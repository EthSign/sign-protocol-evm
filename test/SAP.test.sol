// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {SAP} from "../src/core/SAP.sol";
import {ISAP} from "../src/interfaces/ISAP.sol";
import {MockResolver} from "../src/mock/MockResolver.sol";
import {Schema, DataLocation} from "../src/models/Schema.sol";
import {Attestation} from "../src/models/Attestation.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SAPTest is Test {
    ISAP public sap;
    MockResolver public mockResolver;
    MockERC20 public mockERC20;
    address public prankSender = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
    address public prankRecipient0 = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
    address public prankRecipient1 = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    event SchemaRegistered(string schemaId);
    event AttestationMade(string attestationId);
    event AttestationRevoked(string attestationId, string reason);
    event OffchainAttestationMade(string attestationId);
    event OffchainAttestationRevoked(string attestationId, string reason);

    error SchemaIdInvalid();
    error SchemaExists(string existingSchemaId);
    error SchemaNonexistent(string nonexistentSchemaId);
    error AttestationIrrevocable(string schemaId, string offendingAttestationId);
    error AttestationExists(string existingAttestationId);
    error AttestationNonexistent(string nonexistentAttestationId);
    error AttestationInvalidDuration(string offendingAttestationId, uint64 maxDuration, uint64 inputDuration);
    error AttestationAlreadyRevoked(string offendingAttestationId);
    error AttestationWrongAttester(address expected, address actual);

    function setUp() public {
        sap = new SAP();
        mockResolver = new MockResolver();
        mockERC20 = new MockERC20();
    }

    function test_register() public {
        (string[] memory schemaIds, Schema[] memory schemas) = _createMockSchemas();
        // Trigger `SchemaIdInvalid`
        schemaIds[0] = "";
        vm.expectRevert(abi.encodeWithSelector(SchemaIdInvalid.selector));
        sap.registerBatch(schemaIds, schemas);
        // Register 2 different schema, check events & storage
        (schemaIds,) = _createMockSchemas();
        vm.expectEmit();
        emit SchemaRegistered(schemaIds[0]);
        vm.expectEmit();
        emit SchemaRegistered(schemaIds[1]);
        sap.registerBatch(schemaIds, schemas);
        Schema memory schema0Expected = schemas[0];
        Schema memory schema1Expected = schemas[1];
        Schema memory schema0Actual = sap.getSchema(schemaIds[0]);
        Schema memory schema1Actual = sap.getSchema(schemaIds[1]);
        assertEq(schema0Expected.schema, schema0Actual.schema);
        assertEq(schema0Expected.revocable, schema0Actual.revocable);
        assertEq(address(schema0Expected.resolver), address(schema0Actual.resolver));
        assertEq(schema0Expected.maxValidFor, schema0Actual.maxValidFor);
        assertEq(schema1Expected.schema, schema1Actual.schema);
        assertEq(schema1Expected.revocable, schema1Actual.revocable);
        assertEq(address(schema1Expected.resolver), address(schema1Actual.resolver));
        assertEq(schema1Expected.maxValidFor, schema1Actual.maxValidFor);
        // Register the same schemas with the same IDs, check revert
        vm.expectRevert(abi.encodeWithSelector(SchemaExists.selector, schemaIds[0]));
        sap.registerBatch(schemaIds, schemas);
    }

    function test_attest() public {
        // Register 2 different schemas
        (string[] memory schemaIds, Schema[] memory schemas) = _createMockSchemas();
        sap.registerBatch(schemaIds, schemas);
        // Create two normal attestations
        (string[] memory attestationIds, Attestation[] memory attestations) = _createMockAttestations(schemaIds);
        // Modify the second one to trigger `AttestationInvalidDuration`
        attestations[1].validUntil = uint64(attestations[1].validUntil + schemas[1].maxValidFor + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                AttestationInvalidDuration.selector,
                attestationIds[1],
                schemas[1].maxValidFor,
                attestations[1].validUntil - block.timestamp
            )
        );
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        // Reset and trigger `SchemaNonexistent`
        (, attestations) = _createMockAttestations(schemaIds);
        attestations[1].schemaId = "asdasd";
        vm.expectRevert(abi.encodeWithSelector(SchemaNonexistent.selector, attestations[1].schemaId));
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        // Reset and trigger `AttestationNonexistent` for a linked attestation
        (, attestations) = _createMockAttestations(schemaIds);
        string memory nonexistentAttestationId = "asdasdasd";
        attestations[1].linkedAttestationId = nonexistentAttestationId;
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, nonexistentAttestationId));
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        // Reset and trigger `AttestationWrongAttester` for a linked attestation
        (, attestations) = _createMockAttestations(schemaIds);
        attestations[1].attester = prankRecipient0;
        attestations[1].linkedAttestationId = attestationIds[0];
        vm.prank(prankSender);
        sap.attest(attestationIds[0], attestations[0]);
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, prankRecipient0));
        vm.prank(prankRecipient0);
        sap.attest(attestationIds[1], attestations[1]);
        // Reset and make attest normally
        (, attestations) = _createMockAttestations(schemaIds);
        attestationIds[0] = "A0";
        attestations[1].linkedAttestationId = attestationIds[0];
        vm.expectEmit();
        emit AttestationMade(attestationIds[0]);
        emit AttestationMade(attestationIds[1]);
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        // Attest duplicate and trigger `AttestationExists`
        vm.expectRevert(abi.encodeWithSelector(AttestationExists.selector, attestationIds[0]));
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        // Check storage
        Attestation memory attestation0Actual = sap.getAttestation(attestationIds[0]);
        Attestation memory attestation1Actual = sap.getAttestation(attestationIds[1]);
        assertEq(attestation0Actual.attester, prankSender);
        assertEq(attestation0Actual.schemaId, attestations[0].schemaId);
        assertEq(attestation1Actual.attester, prankSender);
        assertEq(attestation1Actual.schemaId, attestations[1].schemaId);
    }

    function test_revokeFail() public {
        // Register 2 different schemas
        (string[] memory schemaIds, Schema[] memory schemas) = _createMockSchemas();
        sap.registerBatch(schemaIds, schemas);
        // Make two normal attestations
        (string[] memory attestationIds, Attestation[] memory attestations) = _createMockAttestations(schemaIds);
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        string[] memory reasons = _createMockReasons();
        // Trigger `AttestationNonexistent`
        attestationIds[0] = "asdasd";
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, attestationIds[0]));
        vm.prank(prankSender);
        sap.revokeBatch(attestationIds, reasons);
        // Trigger `AttestationIrrevocable`
        (attestationIds,) = _createMockAttestations(schemaIds);
        vm.expectRevert(abi.encodeWithSelector(AttestationIrrevocable.selector, schemaIds[1], attestationIds[1]));
        vm.prank(prankSender);
        sap.revokeBatch(attestationIds, reasons);
        // Trigger `AttestationWrongAttester`
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, address(this)));
        sap.revokeBatch(attestationIds, reasons);
    }

    function test_revoke() public {
        // Register 2 different schemas
        (string[] memory schemaIds, Schema[] memory schemas) = _createMockSchemas();
        schemas[1].revocable = true;
        sap.registerBatch(schemaIds, schemas);
        // Make two normal attestations
        (string[] memory attestationIds, Attestation[] memory attestations) = _createMockAttestations(schemaIds);
        vm.prank(prankSender);
        sap.attestBatch(attestationIds, attestations);
        string[] memory reasons = _createMockReasons();
        // Revoke normally
        vm.expectEmit();
        emit AttestationRevoked(attestationIds[0], reasons[0]);
        emit AttestationRevoked(attestationIds[1], reasons[1]);
        vm.prank(prankSender);
        sap.revokeBatch(attestationIds, reasons);
        // Revoke again and trigger `AttestationAlreadyRevoked`
        vm.expectRevert(abi.encodeWithSelector(AttestationAlreadyRevoked.selector, attestationIds[0]));
        vm.prank(prankSender);
        sap.revokeBatch(attestationIds, reasons);
    }

    function test_attestOffchain() public {
        string[] memory attestationIds = _createMockAttestationIds();
        // Attest normally
        vm.expectEmit();
        emit OffchainAttestationMade(attestationIds[0]);
        emit OffchainAttestationMade(attestationIds[1]);
        sap.attestOffchainBatch(attestationIds);
        // Attest again, trigger `AttestationExists`
        vm.expectRevert(abi.encodeWithSelector(AttestationExists.selector, attestationIds[0]));
        sap.attestOffchainBatch(attestationIds);
    }

    function test_revokeOffchain() public {
        string[] memory attestationIds = _createMockAttestationIds();
        string[] memory reasons = _createMockReasons();
        // Revoke, trigger `AttestationNonexistent`
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, attestationIds[0]));
        sap.revokeOffchainBatch(attestationIds, reasons);
        // Attest normally
        vm.warp(2); // Set block.timestamp to 2 to revoke checks aren't incorrectly tripped
        sap.attestOffchainBatch(attestationIds);
        // Revoke normally
        vm.expectEmit();
        emit OffchainAttestationRevoked(attestationIds[0], reasons[0]);
        emit OffchainAttestationRevoked(attestationIds[1], reasons[1]);
        sap.revokeOffchainBatch(attestationIds, reasons);
    }

    function _createMockSchemas() internal view returns (string[] memory, Schema[] memory) {
        string memory schemaId0 = "schemaId0";
        Schema memory schema0 = Schema({
            revocable: true,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 0,
            resolver: mockResolver,
            schema: "stupid0"
        });
        string memory schemaId1 = "schemaId1";
        Schema memory schema1 = Schema({
            revocable: false,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 100,
            resolver: mockResolver,
            schema: "stupid1"
        });
        string[] memory schemaIds = new string[](2);
        schemaIds[0] = schemaId0;
        schemaIds[1] = schemaId1;
        Schema[] memory schemas = new Schema[](2);
        schemas[0] = schema0;
        schemas[1] = schema1;
        return (schemaIds, schemas);
    }

    function _createMockRecipient() internal view returns (address[] memory) {
        address[] memory addresses = new address[](1);
        addresses[0] = prankRecipient0;
        return addresses;
    }

    function _createMockRecipients() internal view returns (address[] memory) {
        address[] memory addresses = new address[](2);
        addresses[0] = prankRecipient0;
        addresses[1] = prankRecipient1;
        return addresses;
    }

    function _createMockAttestationIds() internal pure returns (string[] memory) {
        string memory attestationId0 = "attestationId0";
        string memory attestationId1 = "attestationId1";
        string[] memory attestationIds = new string[](2);
        attestationIds[0] = attestationId0;
        attestationIds[1] = attestationId1;
        return attestationIds;
    }

    function _createMockAttestations(string[] memory schemaIds)
        internal
        view
        returns (string[] memory, Attestation[] memory)
    {
        string memory attestationId0 = "attestationId0";
        Attestation memory attestation0 = Attestation({
            schemaId: schemaIds[0],
            linkedAttestationId: "",
            data: "",
            attester: prankSender,
            validUntil: uint64(block.timestamp),
            revoked: false,
            recipients: _createMockRecipients()
        });
        string memory attestationId1 = "attestationId1";
        Attestation memory attestation1 = Attestation({
            schemaId: schemaIds[1],
            linkedAttestationId: "",
            data: "",
            attester: prankSender,
            validUntil: uint64(block.timestamp),
            revoked: false,
            recipients: _createMockRecipients()
        });
        string[] memory attestationIds = new string[](2);
        attestationIds[0] = attestationId0;
        attestationIds[1] = attestationId1;
        Attestation[] memory attestations = new Attestation[](2);
        attestations[0] = attestation0;
        attestations[1] = attestation1;
        return (attestationIds, attestations);
    }

    function _createMockReasons() internal pure returns (string[] memory) {
        string[] memory reasons = new string[](2);
        reasons[0] = "Reason 1";
        reasons[1] = "Reason 2";
        return reasons;
    }

    function _createMockResolverFeesETH() internal pure returns (uint256[] memory, uint256) {
        uint256[] memory fees = new uint256[](2);
        fees[0] = 1 ether;
        fees[1] = 4 ether;
        return (fees, 5 ether);
    }
}
