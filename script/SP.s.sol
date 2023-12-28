// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SP} from "../src/core/SP.sol";

contract SPDeploymentScript is Script {
    function run() public {
        _deploy();
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
        Upgrades.upgradeProxy(0xcF220423c825d6fBAcE852eF5edCb0D9e8499AC5, "SP.sol", abi.encodeCall(SP.initialize, ()));
        vm.stopBroadcast();
    }
}