// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from "forge-std/console.sol";
import { SPDeployBase } from "./SPDeployBase.sol";

contract DeploySPProxy is SPDeployBase {
    function run() public {
        vm.startBroadcast(_deployer);
        _assertBroadcastSenderMatchesDeployer();

        address implementation = _resolveSPImplementation();
        address proxy = _deploySPProxy(implementation);

        _checkChainAndSetOwner(proxy);
        console.log("SP proxy:", proxy);
        console.log("SP implementation:", implementation);

        _afterAll();
        vm.stopBroadcast();
    }
}
