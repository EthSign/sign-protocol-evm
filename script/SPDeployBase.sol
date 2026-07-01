// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from "forge-std/console.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { CreateXHelper } from "foundry-deployer/CreateXHelper.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SP } from "../src/core/SP.sol";

interface IOwnableUpgradeable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

abstract contract SPDeployBase is CreateXHelper {
    error DeploymentAddressMismatch(address computed, address deployed);
    error BroadcastSenderMismatch(address expected, address actual);
    error ProxyOwnerNotDeployer(address currentOwner, address expectedDeployer);
    error ProdOwnerRequired(uint256 chainId);

    string internal constant DEPLOYMENT_CATEGORY = "sp";
    string internal constant DEFAULT_IMPL_SALT_ID = "sign-protocol/SP/implementation/v1.1.4";
    string internal constant DEFAULT_PROXY_SALT_ID = "sign-protocol/SP/proxy/v1";
    bytes1 internal constant CROSSCHAIN_REDEPLOY_PROTECTION_DISABLED = 0x00;

    string public jsonPath;
    string public jsonPathLatest;
    string public jsonObjKeyDiff;
    string public jsonObjKeyAll;
    string public finalJson;
    string public finalJsonLatest;
    bool internal _hasNewDeployments;
    address internal _deployer;
    address internal _PROD_OWNER;
    address internal _ALLOWED_DEPLOYMENT_SENDER;
    uint256[] internal _MAINNET_CHAIN_IDS;

    function setUp() public virtual {
        _ensureCreateX();

        _deployer = vm.envOr("DEPLOYER", msg.sender);
        _PROD_OWNER = vm.envOr("PROD_OWNER", address(0));
        _ALLOWED_DEPLOYMENT_SENDER = vm.envOr("ALLOWED_DEPLOYMENT_SENDER", address(0));
        uint256[] memory emptyChainIds;
        _MAINNET_CHAIN_IDS = vm.envOr("MAINNET_CHAIN_IDS", ",", emptyChainIds);

        string memory unixTime = vm.toString(vm.unixTime());
        jsonPath = string.concat(
            vm.projectRoot(),
            "/deployments/",
            DEPLOYMENT_CATEGORY,
            "/",
            vm.toString(block.chainid),
            "-",
            unixTime,
            ".json"
        );
        jsonPathLatest = string.concat(
            vm.projectRoot(), "/deployments/", DEPLOYMENT_CATEGORY, "/", vm.toString(block.chainid), "-latest.json"
        );
        jsonObjKeyDiff = "sp_deploymentObjKeyDiff";
        jsonObjKeyAll = "sp_deploymentObjKeyAll";
    }

    function _implementationSaltId() internal view returns (string memory) {
        return vm.envOr("SP_IMPL_SALT_ID", DEFAULT_IMPL_SALT_ID);
    }

    function _proxySaltId() internal view returns (string memory) {
        return vm.envOr("SP_PROXY_SALT_ID", DEFAULT_PROXY_SALT_ID);
    }

    function _spImplementationCreationCode() internal pure returns (bytes memory) {
        return type(SP).creationCode;
    }

    function _spProxyCreationCode(address implementation) internal view returns (bytes memory) {
        uint64 schemaCounter = uint64(vm.envOr("INITIAL_SCHEMA_COUNTER", uint256(1)));
        uint64 attestationCounter = uint64(vm.envOr("INITIAL_ATTESTATION_COUNTER", uint256(1)));
        bytes memory initData = abi.encodeCall(SP.initialize, (schemaCounter, attestationCounter));
        return abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initData));
    }

    function _saltFromId(string memory saltId) internal view returns (bytes32) {
        bytes11 randomSeed = bytes11(keccak256(abi.encode(saltId)));
        return bytes32(abi.encodePacked(_deployer, CROSSCHAIN_REDEPLOY_PROTECTION_DISABLED, randomSeed));
    }

    function _computeCreate3Address(bytes32 salt) internal view returns (address) {
        return createX.computeCreate3Address(_guardSalt(salt), address(createX));
    }

    function _deploySPImplementation() internal returns (address implementation) {
        implementation = _deployCreate3Artifact(
            _saltFromId(_implementationSaltId()), _spImplementationCreationCode(), "SPImplementation"
        );
    }

    function _resolveSPImplementation() internal returns (address implementation) {
        implementation = vm.envOr("SP_IMPLEMENTATION", address(0));
        if (implementation != address(0)) {
            console.log("Using SP_IMPLEMENTATION override:", implementation);
            return implementation;
        }
        return _deploySPImplementation();
    }

    function _deploySPProxy(address implementation) internal returns (address proxy) {
        proxy = _deployCreate3Artifact(_saltFromId(_proxySaltId()), _spProxyCreationCode(implementation), "SPProxy");
    }

    function _deployCreate3Artifact(
        bytes32 salt,
        bytes memory creationCode,
        string memory artifactKey
    )
        internal
        returns (address deployed)
    {
        address computed = _computeCreate3Address(salt);
        finalJsonLatest = vm.serializeAddress(jsonObjKeyAll, artifactKey, computed);

        if (computed.code.length != 0) {
            console.log("%s already deployed at %s", artifactKey, computed);
            return computed;
        }

        deployed = createX.deployCreate3(salt, creationCode);
        if (computed != deployed) revert DeploymentAddressMismatch(computed, deployed);

        _hasNewDeployments = true;
        finalJson = vm.serializeAddress(jsonObjKeyDiff, artifactKey, deployed);
        console.log("%s deployed at %s", artifactKey, deployed);
    }

    function _checkChainAndSetOwner(address proxy) internal {
        if (_PROD_OWNER == address(0)) {
            if (_isMainnetChain(block.chainid)) revert ProdOwnerRequired(block.chainid);
            console.log("PROD_OWNER not set, skipping owner reassignment.");
            return;
        }
        if (!_isMainnetChain(block.chainid)) {
            console.log("Chain not listed in MAINNET_CHAIN_IDS. PROD_OWNER is set, requiring owner reassignment.");
        }

        address currentOwner = IOwnableUpgradeable(proxy).owner();
        if (currentOwner == _PROD_OWNER) {
            console.log("Owner already set to PROD_OWNER for proxy:", proxy);
            return;
        }
        if (currentOwner != _deployer) revert ProxyOwnerNotDeployer(currentOwner, _deployer);

        IOwnableUpgradeable(proxy).transferOwnership(_PROD_OWNER);
        console.log("Owner reassigned to PROD_OWNER for proxy:", proxy);
    }

    function _afterAll() internal {
        if (_deployer != _ALLOWED_DEPLOYMENT_SENDER) {
            console.log("Skipping deployment save. Deployer does not match ALLOWED_DEPLOYMENT_SENDER.");
            return;
        }

        vm.createDir(string.concat(vm.projectRoot(), "/deployments/", DEPLOYMENT_CATEGORY), true);
        if (bytes(finalJsonLatest).length > 0) {
            vm.writeJson(finalJsonLatest, jsonPathLatest);
        }
        if (_hasNewDeployments) {
            vm.writeJson(finalJson, jsonPath);
        }
    }

    function _assertBroadcastSenderMatchesDeployer() internal {
        (VmSafe.CallerMode callerMode, address msgSender,) = vm.readCallers();
        if (callerMode == VmSafe.CallerMode.Broadcast || callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
            if (msgSender != _deployer) revert BroadcastSenderMismatch(_deployer, msgSender);
        }
    }

    function _isMainnetChain(uint256 chainId) internal view returns (bool) {
        for (uint256 i = 0; i < _MAINNET_CHAIN_IDS.length; i++) {
            if (_MAINNET_CHAIN_IDS[i] == chainId) return true;
        }
        return false;
    }

    function _guardSalt(bytes32 salt) internal view returns (bytes32) {
        return _guardSaltForSender(salt, _deployer);
    }

    function _guardSaltForSender(bytes32 salt, address sender) internal pure returns (bytes32) {
        bytes1 flag = salt[20];
        // CreateX embeds the guarded sender in the first 20 bytes of the salt.
        // forge-lint: disable-next-line(unsafe-typecast)
        address embedded = address(bytes20(salt));

        if (embedded == sender) {
            if (flag == CROSSCHAIN_REDEPLOY_PROTECTION_DISABLED) {
                return _efficientHash(bytes32(uint256(uint160(sender))), salt);
            }
        }

        return keccak256(abi.encode(salt));
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            hash := keccak256(0x00, 0x40)
        }
    }
}
