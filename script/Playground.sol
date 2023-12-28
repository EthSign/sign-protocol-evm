// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ISAP} from "../src/interfaces/ISAP.sol";
import {ISAPResolver} from "../src/interfaces/ISAPResolver.sol";
import {Schema} from "../src/models/Schema.sol";
import {Attestation} from "../src/models/Attestation.sol";
import {DataLocation, URIPointer} from "../src/models/OffchainResource.sol";

contract Playground is Script {
    function run() public {
        ISAP instance = ISAP(0xF1652Cd77b01Adad92456C6a4cf860C4Cc082b8f);
        _register(instance);
        _attest0(instance);
        _attest1(instance);
    }

    function _register(ISAP instance) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.register(
            "subgraph test schema id 0",
            URIPointer({dataLocation: DataLocation.ARWEAVE, uri: "5Kek9vNs3Gd7I30wqDq9ANdYPBtM2STi1GasyBWZ_hs"}),
            Schema({
                revocable: true,
                dataLocation: DataLocation.ONCHAIN,
                maxValidFor: 120,
                resolver: ISAPResolver(address(0)),
                schema: "subgraph test schema 0"
            })
        );
        instance.register(
            "subgraph test schema id 1",
            URIPointer({
                dataLocation: DataLocation.IPFS,
                uri: "bafkreic6oods6alkjbuyc46x63hpe2tqmerg552x4u5gkqaoaq5zdhkzfm"
            }),
            Schema({
                revocable: true,
                dataLocation: DataLocation.ONCHAIN,
                maxValidFor: 120,
                resolver: ISAPResolver(address(0)),
                schema: "subgraph test schema 1"
            })
        );
        vm.stopBroadcast();
    }

    function _attest0(ISAP instance) internal {
        string memory attestationId = "test attestation id 0";
        address[] memory recipients = new address[](2);
        recipients[0] = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
        recipients[1] = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
        Attestation memory attestation = Attestation({
            schemaId: "test schema id 0",
            linkedAttestationId: "",
            data: "some data 0",
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

    function _attest1(ISAP instance) internal {
        string memory attestationId = "test attestation id 1";
        address[] memory recipients = new address[](2);
        recipients[0] = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
        recipients[1] = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
        Attestation memory attestation = Attestation({
            schemaId: "test schema id 0",
            linkedAttestationId: "test attestation id 0",
            data: "some data 1",
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
