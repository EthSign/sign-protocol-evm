// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ISAP} from "../src/interfaces/ISAP.sol";
import {ISAPResolver} from "../src/interfaces/ISAPResolver.sol";
import {Schema, DataLocation} from "../src/models/Schema.sol";
import {Attestation} from "../src/models/Attestation.sol";

contract Playground is Script {
    function run() public {
        ISAP instance = ISAP(0x9aaB2Dc850096891BD89D06866E1011C41EEa80D);
        // _register(instance);
        _attest(instance);
    }

    function _register(ISAP instance) internal {
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
        vm.stopBroadcast();
    }

    function _attest(ISAP instance) internal {
        string memory attestationId = "test attestation id 1";
        address[] memory recipients = new address[](2);
        recipients[0] = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
        recipients[1] = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
        Attestation memory attestation = Attestation({
            schemaId: "test schema id 0",
            linkedAttestationId: "test attestation id 0",
            attester: 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094,
            validUntil: uint64(block.timestamp + 119),
            revoked: false,
            recipients: recipients
        });
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.attest(attestationId, attestation);
        vm.stopBroadcast();
    }
}
