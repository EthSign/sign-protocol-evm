// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ISAP} from "../src/interfaces/ISAP.sol";
import {ISAPResolver} from "../src/interfaces/ISAPResolver.sol";
import {Schema, DataLocation} from "../src/models/Schema.sol";
import {Attestation} from "../src/models/Attestation.sol";

contract Playground is Script {
    function run() public {
        ISAP instance = ISAP(0xcF220423c825d6fBAcE852eF5edCb0D9e8499AC5);
        string memory schemaId = "test schema id 0";
        Schema memory schema = Schema({
            revocable: true,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 120,
            resolver: ISAPResolver(address(0)),
            schema: "test schema 0"
        });
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.register(schemaId, schema);
    }
}
