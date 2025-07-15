// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployHelper} from "./Helper/DeployHelper.sol";
import {SP} from "../src/core/SP.sol";

contract DeploySignProtocol is DeployHelper {
    function setUp () public override {
       _setUp("SignProtocol");
    }

    function run() public {
        SP signProtocol = SP(
            _deploy(type(SP).creationCode)
        );

        signProtocol.initialize(1, 1);

        _checkChainAndSetOwner(address(signProtocol));
        
        _afterAll();
    }
}