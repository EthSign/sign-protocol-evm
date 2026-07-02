// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from "forge-std/console.sol";
import { SPDeployBase } from "./SPDeployBase.sol";

contract DeploySPImplementation is SPDeployBase {
    function run() public {
        vm.startBroadcast(_deployer);
        _assertBroadcastSenderMatchesDeployer();

        address implementation = _deploySPImplementation();
        console.log("SP implementation:", implementation);

        _afterAll();
        vm.stopBroadcast();
    }
}
