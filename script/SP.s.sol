// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SP} from "../src/core/SP.sol";

contract SPDeploymentScript is Script {
    function run() public {
        _deploy();
        //_upgrade();
    }

    function _deploy() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Upgrades.deployUUPSProxy("SP.sol", abi.encodeCall(SP.initialize, ()));
        vm.stopBroadcast();
    }

    function _upgrade() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Upgrades.upgradeProxy(
            0x76459e57b9C6D5Ee74FAcf841c36a17FC2fD1a05,
            "SP.sol",
            "",
            Options({
                referenceContract: "SP-old.sol:SP",
                constructorData: "",
                unsafeAllow: "",
                unsafeAllowRenames: false,
                unsafeSkipStorageCheck: false,
                unsafeSkipAllChecks: false
            })
        );
        vm.stopBroadcast();
    }
}
