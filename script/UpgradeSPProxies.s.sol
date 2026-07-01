// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from "forge-std/console.sol";
import { SPDeployBase } from "./SPDeployBase.sol";
import { SPProxyRegistry } from "./SPProxyRegistry.sol";

interface IUUPSProxy {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

interface ISPVersion {
    function version() external view returns (string memory);
}

contract UpgradeSPProxies is SPDeployBase, SPProxyRegistry {
    error NoKnownSPProxies(uint256 chainId);
    error ProxySelectionRequired(uint256 chainId);
    error ProxyHasNoCode(address proxy);
    error ProxyAlreadyUsesImplementation(address proxy, address implementation);
    error ProxyImplementationMismatch(address proxy, address expected, address actual);
    error ProxyVersionMismatch(address proxy, string expected, string actual);

    string internal constant EXPECTED_SP_VERSION = "1.1.4";
    bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function run() public {
        vm.startBroadcast(_deployer);
        _assertBroadcastSenderMatchesDeployer();

        address implementation = _resolveSPImplementation();
        bytes memory upgradeCallData = vm.envOr("UPGRADE_CALLDATA", bytes(""));
        address explicitProxy = vm.envOr("SP_PROXY", address(0));

        if (explicitProxy != address(0)) {
            _upgradeProxy(explicitProxy, implementation, upgradeCallData);
        } else if (vm.envOr("UPGRADE_ALL_KNOWN_PROXIES", false)) {
            address[] memory proxies = _knownSPProxies(block.chainid);
            if (proxies.length == 0) revert NoKnownSPProxies(block.chainid);
            for (uint256 i = 0; i < proxies.length; i++) {
                _upgradeProxy(proxies[i], implementation, upgradeCallData);
            }
        } else {
            revert ProxySelectionRequired(block.chainid);
        }

        _afterAll();
        vm.stopBroadcast();
    }

    function _upgradeProxy(address proxy, address implementation, bytes memory upgradeCallData) internal {
        if (proxy.code.length == 0) revert ProxyHasNoCode(proxy);

        address oldImplementation = _proxyImplementation(proxy);
        if (oldImplementation == implementation && upgradeCallData.length == 0) {
            revert ProxyAlreadyUsesImplementation(proxy, implementation);
        }

        string memory oldVersion = _readVersion(proxy);
        IUUPSProxy(proxy).upgradeToAndCall(implementation, upgradeCallData);
        address actualImplementation = _proxyImplementation(proxy);
        if (actualImplementation != implementation) {
            revert ProxyImplementationMismatch(proxy, implementation, actualImplementation);
        }

        string memory newVersion = _readVersion(proxy);
        string memory expectedVersion = vm.envOr("SP_EXPECTED_VERSION", EXPECTED_SP_VERSION);
        if (!_stringEq(newVersion, expectedVersion)) {
            revert ProxyVersionMismatch(proxy, expectedVersion, newVersion);
        }

        finalJsonLatest = vm.serializeAddress(jsonObjKeyAll, string.concat("SPProxy-", vm.toString(proxy)), proxy);
        console.log("Upgraded SP proxy:", proxy);
        console.log("  old implementation:", oldImplementation);
        console.log("  new implementation:", implementation);
        console.log("  old version:", oldVersion);
        console.log("  new version:", newVersion);
    }

    function _proxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967_IMPLEMENTATION_SLOT))));
    }

    function _readVersion(address proxy) internal view returns (string memory) {
        try ISPVersion(proxy).version() returns (string memory version) {
            return version;
        } catch {
            return "unknown";
        }
    }

    function _stringEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
