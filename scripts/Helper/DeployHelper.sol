// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CreateXScript} from "./CreateX/CreateXScript.sol";
import {IVersionable} from "./interfaces/IVersionable.sol";
import {strings} from "./utils/strings.sol";

/**
 * @title DeployHelper
 * @notice A reusable deployment helper that extends CreateXScript for deterministic deployments
 * @dev Assumes all contracts implement IVersionable with format "x.x.x-ContractName"
 *      Automatically saves deployment info and verification JSONs
 */
abstract contract DeployHelper is CreateXScript, IVersionable {
    using strings for *;

    // Deployment tracking
    string public jsonPath;
    string public jsonPathLatest;
    string public jsonObjKeyDiff;
    string public jsonObjKeyAll;
    string public finalJson;
    string public finalJsonLatest;
    string public unixTime;
    bool internal _hasNewDeployments;

    // Environment variables
    address internal _PROD_OWNER;
    uint256[] internal _MAINNET_CHAIN_IDS;
    bool internal _FORCE_DEPLOY;
    address internal _ALLOWED_DEPLOYMENT_SENDER;

    // Events
    event ContractDeployed(string indexed version, address indexed contractAddress, string contractName);
    event OwnershipTransferred(address indexed contractAddress, address indexed newOwner);

    /**
     * @notice Must be overridden by implementing contracts
     * @dev Should call _setUp(string) with the deployment subfolder name
     */
    function setUp() public virtual {
        revert("Must override and call `_setUp(string)`!");
    }

    /**
     * @notice Internal setup function to initialize deployment paths
     * @param subfolder The deployment subfolder for organizing deployments
     */
    function _setUp(string memory subfolder) internal withCreateX {
        // Read environment variables from .env
        _PROD_OWNER = vm.envAddress("PROD_OWNER");
        _MAINNET_CHAIN_IDS = vm.envUint("MAINNET_CHAIN_IDS", ",");
        _FORCE_DEPLOY = vm.envOr("FORCE_DEPLOY", false);
        _ALLOWED_DEPLOYMENT_SENDER = vm.envOr("ALLOWED_DEPLOYMENT_SENDER", address(0));

        unixTime = vm.toString(vm.unixTime());

        // Create necessary directories
        string[] memory inputs = new string[](3);
        inputs[0] = "mkdir";
        inputs[1] = "-p";
        inputs[2] = string.concat(vm.projectRoot(), "/deployments/", subfolder);
        vm.ffi(inputs);

        inputs[2] = string.concat(vm.projectRoot(), "/deployments/", subfolder, "/standard-json-inputs");
        vm.ffi(inputs);

        jsonPath = string.concat(
            vm.projectRoot(),
            "/deployments/",
            subfolder,
            "/",
            vm.toString(block.chainid),
            "-",
            _getUnixHost(),
            "-",
            unixTime,
            ".json"
        );
        jsonPathLatest =
            string.concat(vm.projectRoot(), "/deployments/", subfolder, "/", vm.toString(block.chainid), "-latest.json");
        jsonObjKeyDiff = "deploymentObjKeyDiff";
        jsonObjKeyAll = "deploymentObjKeyAll";
    }

    /**
     * @notice Deploy a contract using CREATE3 for deterministic addresses
     * @param creationCode The contract creation bytecode
     * @return deployed The deployed contract address
     */
    function _deploy(bytes memory creationCode) internal returns (address deployed) {
        // Extract subfolder from jsonPath
        string memory subfolder = _extractSubfolder();
        (bool didDeploy, address deployedAddress) = __deploy(creationCode, subfolder);
        if (didDeploy) {
            // Contract was newly deployed
        }
        return deployedAddress;
    }

    /**
     * @notice Deploy a contract with custom salt suffix
     * @param creationCode The contract creation bytecode
     * @param saltSuffix Custom suffix for the salt
     * @return deployed The deployed contract address
     */
    function _deployWithSalt(bytes memory creationCode, string memory saltSuffix) internal returns (address deployed) {
        // Extract subfolder from jsonPath
        string memory subfolder = _extractSubfolder();
        (bool didDeploy, address deployedAddress) = __deployWithSalt(creationCode, saltSuffix, subfolder);
        if (didDeploy) {
            // Contract was newly deployed
        }
        return deployedAddress;
    }

    /**
     * @notice Finalize deployment by writing JSON files
     * @dev Should be called at the end of deployment scripts
     */
    function _afterAll() internal {
        // Only sender specified in .env can save deployments
        if (_ALLOWED_DEPLOYMENT_SENDER != address(0) && msg.sender != _ALLOWED_DEPLOYMENT_SENDER) {
            console.log(
                unicode"⚠️[WARN] Skipping deployment save. Sender %s does not match allowed sender %s",
                msg.sender,
                _ALLOWED_DEPLOYMENT_SENDER
            );
            return;
        }
        
        if (_hasNewDeployments) {
            vm.writeJson(finalJson, jsonPath);
        }
        vm.writeJson(finalJsonLatest, jsonPathLatest);
    }

    /**
     * @notice Check if current chain is production and transfer ownership if needed
     * @param instance The contract instance to check/transfer ownership
     */
    function _checkChainAndSetOwner(address instance) internal {
        bool isMainnet = false;
        for (uint256 i = 0; i < _MAINNET_CHAIN_IDS.length; i++) {
            if (block.chainid == _MAINNET_CHAIN_IDS[i]) {
                isMainnet = true;
                break;
            }
        }

        if (!isMainnet) {
            console.log(unicode"✅[INFO] Testnet detected, skipping owner reassignment.");
            return;
        }

        if (_PROD_OWNER == address(0)) {
            console.log(unicode"⚠️[WARN] Production chain detected but no production owner configured.");
            return;
        }

        if (Ownable(instance).owner() == _PROD_OWNER) {
            console.log(unicode"✅[INFO] Owner already set to %s for %s, skipping reassignment.", _PROD_OWNER, instance);
            return;
        }

        vm.broadcast();
        Ownable(instance).transferOwnership(_PROD_OWNER);
        console.log(unicode"✅[INFO] Production chain detected, owner reassigned to %s for %s.", _PROD_OWNER, instance);

        emit OwnershipTransferred(instance, _PROD_OWNER);
    }

    /**
     * @notice Generate salt for CREATE3 deployment
     * @param versionString The version string from the contract
     * @return salt The generated salt
     */
    function _getSalt(string memory versionString) internal view returns (bytes32) {
        bytes1 crosschainProtectionFlag = bytes1(0x00); // 0: allow crosschain, 1: disallow crosschain
        bytes11 randomSeed = bytes11(keccak256(abi.encode(versionString)));
        return bytes32(abi.encodePacked(msg.sender, crosschainProtectionFlag, randomSeed));
    }

    /**
     * @notice Generate salt with custom suffix
     * @param versionString The version string from the contract
     * @param suffix Custom suffix for the salt
     * @return salt The generated salt
     */
    function _getSaltWithSuffix(string memory versionString, string memory suffix) internal view returns (bytes32) {
        bytes1 crosschainProtectionFlag = bytes1(0x00);
        bytes11 randomSeed = bytes11(keccak256(abi.encode(versionString, suffix)));
        return bytes32(abi.encodePacked(msg.sender, crosschainProtectionFlag, randomSeed));
    }

    /**
     * @notice Internal deployment function with automatic version detection
     * @param creationCode The contract creation bytecode
     * @return didDeploy Whether the contract was newly deployed
     * @return deployed The deployed contract address
     */
    function __deploy(bytes memory creationCode, string memory subfolder) private returns (bool, address) {
        (string memory name, string memory versionAndVariant) = _getNameVersionAndVariant(creationCode);
        address computed = computeCreate3Address(_getSalt(versionAndVariant), msg.sender);
        finalJsonLatest = vm.serializeAddress(jsonObjKeyAll, versionAndVariant, computed);

        if (computed.code.length != 0) {
            console.log(unicode"⚠️[WARN] Skipping deployment, %s already deployed at %s", versionAndVariant, computed);
            return (false, computed);
        }

        string memory standardJsonInput = _generateStandardJsonInput(name);

        _checkStandardJsonInput(versionAndVariant, standardJsonInput, subfolder);

        vm.startBroadcast();
        address deployed = create3(_getSalt(versionAndVariant), creationCode);
        vm.stopBroadcast();

        require(computed == deployed, "Computed address mismatch");
        console.log(unicode"✅[INFO] %s deployed at %s", versionAndVariant, computed);
        _hasNewDeployments = true;
        finalJson = vm.serializeAddress(jsonObjKeyDiff, versionAndVariant, computed);
        _saveContractToStandardJsonInput(versionAndVariant, standardJsonInput, subfolder);

        emit ContractDeployed(versionAndVariant, deployed, name);

        return (true, deployed);
    }

    /**
     * @notice Internal deployment function with custom salt
     * @param creationCode The contract creation bytecode
     * @param saltSuffix Custom suffix for the salt
     * @return didDeploy Whether the contract was newly deployed
     * @return deployed The deployed contract address
     */
    function __deployWithSalt(bytes memory creationCode, string memory saltSuffix, string memory subfolder)
        private
        returns (bool, address)
    {
        (string memory name, string memory versionAndVariant) = _getNameVersionAndVariant(creationCode);
        string memory saltKey = string.concat(versionAndVariant, "-", saltSuffix);
        address computed = computeCreate3Address(_getSaltWithSuffix(versionAndVariant, saltSuffix), msg.sender);
        finalJsonLatest = vm.serializeAddress(jsonObjKeyAll, saltKey, computed);

        if (computed.code.length != 0) {
            console.log(unicode"⚠️[WARN] Skipping deployment, %s already deployed at %s", saltKey, computed);
            return (false, computed);
        }

        vm.startBroadcast();
        address deployed = create3(_getSaltWithSuffix(versionAndVariant, saltSuffix), creationCode);
        vm.stopBroadcast();

        require(computed == deployed, "Computed address mismatch");
        console.log(unicode"✅[INFO] %s deployed at %s", saltKey, computed);
        _hasNewDeployments = true;
        finalJson = vm.serializeAddress(jsonObjKeyDiff, saltKey, computed);

        string memory standardJsonInput = _generateStandardJsonInput(name);
        _checkStandardJsonInput(saltKey, standardJsonInput, subfolder);
        _saveContractToStandardJsonInput(saltKey, standardJsonInput, subfolder);

        emit ContractDeployed(saltKey, deployed, name);

        return (true, deployed);
    }

    /**
     * @notice Extract contract name and version from creation code
     * @param creationCode The contract creation bytecode
     * @return name The contract name
     * @return versionAndVariant The full version string (x.x.x-ContractName)
     */
    function _getNameVersionAndVariant(bytes memory creationCode)
        private
        returns (string memory name, string memory versionAndVariant)
    {
        address mockDeploymentAddress;
        assembly {
            mockDeploymentAddress := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        versionAndVariant = IVersionable(mockDeploymentAddress).version();

        // Parse version format: "x.x.x-ContractName"
        strings.slice memory slice = versionAndVariant.toSlice();
        strings.slice memory delimiter = "-".toSlice();
        string[] memory parts = new string[](slice.count(delimiter) + 1);

        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = slice.split(delimiter).toString();
        }

        require(parts.length >= 2, "Invalid version format. Expected: x.x.x-ContractName");
        name = parts[1];
    }

    /**
     * @notice Get current Unix host for deployment tracking
     * @return host The current Unix host
     */
    function _getUnixHost() private returns (string memory) {
        string[] memory inputs = new string[](1);
        inputs[0] = "whoami";
        return string(vm.ffi(inputs));
    }

    /**
     * @notice Generate standard JSON input for contract verification
     * @param contractName The contract name
     * @return The standard JSON input string
     */
    function _generateStandardJsonInput(string memory contractName) private returns (string memory) {
        string[] memory inputs = new string[](5);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = "0x0000000000000000000000000000000000000000";
        inputs[3] = contractName;
        inputs[4] = "--show-standard-json-input";
        return string(vm.ffi(inputs));
    }

    /**
     * @notice Check if standard JSON input already exists and matches
     * @param versionAndVariant The version and variant string
     * @param standardJsonInput The generated standard JSON input
     * @param subfolder The deployment subfolder
     */
    function _checkStandardJsonInput(
        string memory versionAndVariant,
        string memory standardJsonInput,
        string memory subfolder
    ) private view {
        string memory outputPath = string.concat(
            "deployments/", subfolder, "/standard-json-inputs/", versionAndVariant, ".json"
        );

        if (vm.isFile(outputPath)) {
            string memory existingInput = vm.readFile(outputPath);
            if (keccak256(abi.encodePacked(existingInput)) != keccak256(abi.encodePacked(standardJsonInput))) {
                if (!_FORCE_DEPLOY) {
                    revert(
                        string.concat(
                            "Standard JSON input has changed for ",
                            versionAndVariant,
                            ". Set FORCE_DEPLOY=true to proceed."
                        )
                    );
                }
                console.log(
                    unicode"⚠️[WARN] Standard JSON input has changed for %s but FORCE_DEPLOY is enabled",
                    versionAndVariant
                );
            } else {
                console.log(unicode"✅[INFO] Standard JSON input for %s is unchanged", versionAndVariant);
            }
        } else {
            console.log(unicode"ℹ️[INFO] Standard JSON input for %s does not exist, will be created", versionAndVariant);
        }
    }

    /**
     * @notice Save contract verification JSON for Etherscan
     * @param versionAndVariant The version and variant string
     * @param standardJsonInput The standard JSON input to save
     * @param subfolder The deployment subfolder
     */
    function _saveContractToStandardJsonInput(
        string memory versionAndVariant,
        string memory standardJsonInput,
        string memory subfolder
    ) private {
        string memory outputPath = string.concat(
            "deployments/", subfolder, "/standard-json-inputs/", versionAndVariant, ".json"
        );

        if (vm.exists(outputPath) && _FORCE_DEPLOY) {
            outputPath = string.concat(
                "deployments/",
                subfolder,
                "/standard-json-inputs/",
                versionAndVariant,
                "-",
                unixTime,
                ".json"
            );
            console.log(
                unicode"✅[INFO] Standard JSON input for %s saved with timestamp due to FORCE_DEPLOY",
                versionAndVariant
            );
        } else {
            console.log(unicode"✅[INFO] Standard JSON input for %s saved", versionAndVariant);
        }

        vm.writeFile(outputPath, standardJsonInput);
    }

    /**
     * @notice Extract subfolder from jsonPath
     * @return The subfolder name
     */
    function _extractSubfolder() private view returns (string memory) {
        // jsonPath format: deployments/{subfolder}/{chainid}-{host}-{timestamp}.json
        strings.slice memory pathSlice = jsonPath.toSlice();
        strings.slice memory delimiter = "deployments/".toSlice();

        // Skip to after "deployments/"
        pathSlice.split(delimiter);

        // Now get the subfolder (everything before the next "/")
        delimiter = "/".toSlice();
        return pathSlice.split(delimiter).toString();
    }

    function version() external pure override returns (string memory) {
        return "1.1.0-DeployHelper";
    }
}