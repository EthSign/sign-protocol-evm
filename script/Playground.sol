// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ISP} from "../src/interfaces/ISP.sol";
import {ISPResolver} from "../src/interfaces/ISPResolver.sol";
import {Schema} from "../src/models/Schema.sol";
import {Attestation} from "../src/models/Attestation.sol";
import {DataLocation, SchemaMetadata} from "../src/models/OffchainResource.sol";

contract Playground is Script {
    function run() public {
        ISP instance = ISP(0xF7663045Bf818221a72ddd38732Cf76c6b2DF2F5);
        _register(instance);
        _attest0(instance);
        _attest1(instance);
    }

    function _register(ISP instance) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.register(
            "subgraph test schema id 0",
            SchemaMetadata({dataLocation: DataLocation.ARWEAVE, uri: "5Kek9vNs3Gd7I30wqDq9ANdYPBtM2STi1GasyBWZ_hs"}),
            Schema({
                revocable: true,
                dataLocation: DataLocation.ONCHAIN,
                maxValidFor: 120,
                resolver: ISPResolver(address(0)),
                schema: "subgraph test schema 0"
            })
        );
        instance.register(
            "subgraph test schema id 1",
            SchemaMetadata({
                dataLocation: DataLocation.IPFS,
                uri: "bafkreic6oods6alkjbuyc46x63hpe2tqmerg552x4u5gkqaoaq5zdhkzfm"
            }),
            Schema({
                revocable: true,
                dataLocation: DataLocation.ONCHAIN,
                maxValidFor: 120,
                resolver: ISPResolver(address(0)),
                schema: "subgraph test schema 1"
            })
        );
        vm.stopBroadcast();
    }

    function _attest0(ISP instance) internal {
        string memory attestationId = "test attestation id 0";
        address[] memory recipients = new address[](2);
        recipients[0] = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
        recipients[1] = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
        Attestation memory attestation = Attestation({
            schemaId: "subgraph test schema id 0",
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

    function _attest1(ISP instance) internal {
        string memory attestationId = "test attestation id 1";
        address[] memory recipients = new address[](2);
        recipients[0] = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
        recipients[1] = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
        Attestation memory attestation = Attestation({
            schemaId: "subgraph test schema id 0",
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
