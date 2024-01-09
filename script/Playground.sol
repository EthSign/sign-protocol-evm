// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ISP} from "../src/interfaces/ISP.sol";
import {SP} from "../src/core/SP.sol";
import {ISPResolver} from "../src/interfaces/ISPResolver.sol";
import {Schema} from "../src/models/Schema.sol";
import {Attestation} from "../src/models/Attestation.sol";
import {DataLocation} from "../src/models/DataLocation.sol";

contract Playground is Script {
    function run() public {
        ISP instance = ISP(0xB3a90FdDb38b82FB7e1Bab3A32D69a898b44c779);
        _register(instance);
        _attest0(instance);
        _attest1(instance);
    }

    function _register(ISP instance) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.register(
            Schema({
                revocable: true,
                dataLocation: DataLocation.ARWEAVE,
                maxValidFor: 120,
                resolver: ISPResolver(address(0)),
                data: "5Kek9vNs3Gd7I30wqDq9ANdYPBtM2STi1GasyBWZ_hs"
            })
        );
        instance.register(
            Schema({
                revocable: true,
                dataLocation: DataLocation.IPFS,
                maxValidFor: 120,
                resolver: ISPResolver(address(0)),
                data: "bafkreic6oods6alkjbuyc46x63hpe2tqmerg552x4u5gkqaoaq5zdhkzfm"
            })
        );
        vm.stopBroadcast();
    }

    function _attest0(ISP instance) internal {
        bytes[] memory recipients = new bytes[](2);
        recipients[0] = abi.encode(0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094);
        recipients[1] = abi.encode(0x003BBE6Da0EB4963856395829030FcE383a14C53);
        Attestation memory attestation = Attestation({
            schemaId: 1,
            dataLocation: DataLocation.ARWEAVE,
            linkedAttestationId: 0,
            data: "some data 0",
            attester: 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094,
            validUntil: uint64(block.timestamp + 119),
            revoked: false,
            recipients: recipients
        });
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.attest(attestation, "Test index key 0");
        vm.stopBroadcast();
    }

    function _attest1(ISP instance) internal {
        bytes[] memory recipients = new bytes[](2);
        recipients[0] = abi.encode(0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094);
        recipients[1] = abi.encode(0x003BBE6Da0EB4963856395829030FcE383a14C53);
        Attestation memory attestation = Attestation({
            schemaId: 1,
            dataLocation: DataLocation.IPFS,
            linkedAttestationId: 1,
            data: "some data 1",
            attester: 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094,
            validUntil: uint64(block.timestamp + 119),
            revoked: false,
            recipients: recipients
        });
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        instance.attest(attestation, "Test index key 1");
        vm.stopBroadcast();
    }
}
