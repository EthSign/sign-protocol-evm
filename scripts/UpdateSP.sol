// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {SP} from "../src/core/SP.sol";
import {ISPHook} from "../src/interfaces/ISPHook.sol";

contract UpdateSP is Script {
    SP public sp;

    function setUp() public {}

    function run() external {
        address spAddress = vm.envOr("SP_ADDRESS", address(0));
        require(spAddress != address(0), "SP_ADDRESS not set in .env");

        sp = SP(spAddress);

        // Example: Update schema with ID 1
        updateSchema(
            1, // schemaId
            true, // revocable
            365 days, // maxValidFor (1 year)
            ISPHook(address(0)), // no hook
            "Updated schema data"
        );

        // Example: Update attestation with ID 1
        updateAttestation(
            1, // attestationId
            0, // no linked attestation
            block.timestamp + 30 days, // valid for 30 days
            false, // not revoked
            new bytes[](0), // no recipients
            abi.encode("Updated attestation data")
        );

        // Example: Update offchain attestation
        updateOffchainAttestation(
            "offchain-123", // offchainAttestationId
            0x1234567890123456789012345678901234567890, // new attester address
            false // not revoked
        );
    }

    function updateSchema(
        uint64 schemaId,
        bool revocable,
        uint64 maxValidFor,
        ISPHook hook,
        string memory data
    ) public {
        console.log("Updating schema", schemaId);
        vm.startBroadcast();
        sp.modifySchema(schemaId, revocable, maxValidFor, hook, data);
        vm.stopBroadcast();
        console.log("Schema updated successfully");
    }

    function updateAttestation(
        uint64 attestationId,
        uint64 linkedAttestationId,
        uint64 validUntil,
        bool revoked,
        bytes[] memory recipients,
        bytes memory data
    ) public {
        console.log("Updating attestation", attestationId);
        vm.startBroadcast();
        sp.modifyAttestation(
            attestationId,
            linkedAttestationId,
            validUntil,
            revoked,
            recipients,
            data
        );
        vm.stopBroadcast();
        console.log("Attestation updated successfully");
    }

    function updateOffchainAttestation(
        string memory offchainAttestationId,
        address newAttester,
        bool revoke
    ) public {
        console.log("Updating offchain attestation", offchainAttestationId);
        vm.startBroadcast();
        sp.modifyOffchainAttestation(offchainAttestationId, newAttester, revoke);
        vm.stopBroadcast();
        console.log("Offchain attestation updated successfully");
    }

    // Batch update multiple schemas
    function batchUpdateSchemas(
        uint64[] memory schemaIds,
        bool[] memory revocables,
        uint64[] memory maxValidFors,
        ISPHook[] memory hooks,
        string[] memory datas
    ) external {
        require(
            schemaIds.length == revocables.length &&
            schemaIds.length == maxValidFors.length &&
            schemaIds.length == hooks.length &&
            schemaIds.length == datas.length,
            "Array lengths mismatch"
        );

        for (uint256 i = 0; i < schemaIds.length; i++) {
            updateSchema(
                schemaIds[i],
                revocables[i],
                maxValidFors[i],
                hooks[i],
                datas[i]
            );
        }
    }

    // Batch update multiple attestations
    function batchUpdateAttestations(
        uint64[] memory attestationIds,
        uint64[] memory linkedAttestationIds,
        uint64[] memory validUntils,
        bool[] memory revokeds,
        bytes[][] memory recipients,
        bytes[] memory datas
    ) external {
        require(
            attestationIds.length == linkedAttestationIds.length &&
            attestationIds.length == validUntils.length &&
            attestationIds.length == revokeds.length &&
            attestationIds.length == recipients.length &&
            attestationIds.length == datas.length,
            "Array lengths mismatch"
        );

        for (uint256 i = 0; i < attestationIds.length; i++) {
            updateAttestation(
                attestationIds[i],
                linkedAttestationIds[i],
                validUntils[i],
                revokeds[i],
                recipients[i],
                datas[i]
            );
        }
    }
}