// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {SP} from "../src/core/SP.sol";
import {ISP} from "../src/interfaces/ISP.sol";
import {MockResolver} from "../src/mock/MockResolver.sol";
import {Schema} from "../src/models/Schema.sol";
import {DataLocation, SchemaMetadata} from "../src/models/OffchainResource.sol";
import {Attestation} from "../src/models/Attestation.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SPTest is Test {
    ISP public sp;
    MockResolver public mockResolver;
    MockERC20 public mockERC20;
    address public prankSender = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
    address public prankRecipient0 = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
    address public prankRecipient1 = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    event SchemaRegistered(uint256 schemaId, DataLocation metadataDataLocation, string metadataUri);
    event AttestationMade(uint256 attestationId);
    event AttestationRevoked(uint256 attestationId, string reason);
    event OffchainAttestationMade(string attestationId);
    event OffchainAttestationRevoked(string attestationId, string reason);

    error SchemaNonexistent(uint256 nonexistentSchemaId);
    error AttestationIrrevocable(uint256 schemaId, uint256 offendingAttestationId);
    error AttestationNonexistent(uint256 nonexistentAttestationId);
    error AttestationInvalidDuration(uint256 offendingAttestationId, uint64 maxDuration, uint64 inputDuration);
    error AttestationAlreadyRevoked(uint256 offendingAttestationId);
    error AttestationWrongAttester(address expected, address actual);
    error OffchainAttestationExists(string existingOffchainAttestationId);
    error OffchainAttestationNonexistent(string nonexistentOffchainAttestationId);
    error OffchainAttestationAlreadyRevoked(string offendingOffchainAttestationId);

    function setUp() public {
        sp = new SP();
        SP(address(sp)).initialize();
        mockResolver = new MockResolver();
        mockERC20 = new MockERC20();
    }

    function test_register() public {
        (SchemaMetadata[] memory uris, Schema[] memory schemas) = _createMockSchemas();
        // Register 2 different schema, check events & storage
        uint256 currentSchemaCounter = sp.schemaCounter();
        vm.expectEmit();
        emit SchemaRegistered(currentSchemaCounter++, uris[0].dataLocation, uris[0].uri);
        emit SchemaRegistered(currentSchemaCounter++, uris[1].dataLocation, uris[1].uri);
        uint256[] memory schemaIds = sp.registerBatch(uris, schemas);
        Schema memory schema0Expected = schemas[0];
        Schema memory schema1Expected = schemas[1];
        Schema memory schema0Actual = sp.getSchema(schemaIds[0]);
        Schema memory schema1Actual = sp.getSchema(schemaIds[1]);
        assertEq(schema0Expected.schema, schema0Actual.schema);
        assertEq(schema0Expected.revocable, schema0Actual.revocable);
        assertEq(address(schema0Expected.resolver), address(schema0Actual.resolver));
        assertEq(schema0Expected.maxValidFor, schema0Actual.maxValidFor);
        assertEq(schema1Expected.schema, schema1Actual.schema);
        assertEq(schema1Expected.revocable, schema1Actual.revocable);
        assertEq(address(schema1Expected.resolver), address(schema1Actual.resolver));
        assertEq(schema1Expected.maxValidFor, schema1Actual.maxValidFor);
    }

    function test_attest() public {
        // Register 2 different schemas
        (SchemaMetadata[] memory uris, Schema[] memory schemas) = _createMockSchemas();
        uint256[] memory schemaIds = sp.registerBatch(uris, schemas);
        // Create two normal attestations
        Attestation[] memory attestations = _createMockAttestations(schemaIds);
        // Modify the second one to trigger `AttestationInvalidDuration`
        uint256 attestationId0 = sp.attestationCounter();
        attestations[1].validUntil = uint64(attestations[1].validUntil + schemas[1].maxValidFor + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                AttestationInvalidDuration.selector,
                attestationId0 + 1,
                schemas[1].maxValidFor,
                attestations[1].validUntil - block.timestamp
            )
        );
        vm.prank(prankSender);
        sp.attestBatch(attestations);
        // Reset and trigger `SchemaNonexistent`
        attestations = _createMockAttestations(schemaIds);
        attestations[1].schemaId = 100000;
        vm.expectRevert(abi.encodeWithSelector(SchemaNonexistent.selector, attestations[1].schemaId));
        vm.prank(prankSender);
        sp.attestBatch(attestations);
        // Reset and trigger `AttestationNonexistent` for a linked attestation
        attestations = _createMockAttestations(schemaIds);
        uint256 nonexistentAttestationId = 100000;
        attestations[1].linkedAttestationId = nonexistentAttestationId;
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, nonexistentAttestationId));
        vm.prank(prankSender);
        sp.attestBatch(attestations);
        // Reset and trigger `AttestationWrongAttester` for a linked attestation
        attestations = _createMockAttestations(schemaIds);
        attestations[1].attester = prankRecipient0;
        attestations[1].linkedAttestationId = attestationId0;
        vm.expectEmit();
        emit AttestationMade(attestationId0);
        vm.prank(prankSender);
        sp.attest(attestations[0]);
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, prankRecipient0));
        vm.prank(prankRecipient0);
        sp.attest(attestations[1]);
        // Reset and make attest normally
        attestations = _createMockAttestations(schemaIds);
        attestations[1].linkedAttestationId = attestationId0;
        vm.expectEmit();
        emit AttestationMade(attestationId0 + 1);
        vm.prank(prankSender);
        sp.attest(attestations[1]);
        // Check storage
        Attestation memory attestation0Actual = sp.getAttestation(attestationId0);
        Attestation memory attestation1Actual = sp.getAttestation(attestationId0 + 1);
        assertEq(attestation0Actual.attester, prankSender);
        assertEq(attestation0Actual.schemaId, attestations[0].schemaId);
        assertEq(attestation1Actual.attester, prankSender);
        assertEq(attestation1Actual.schemaId, attestations[1].schemaId);
    }

    function test_revokeFail() public {
        // Register 2 different schemas
        (SchemaMetadata[] memory uris, Schema[] memory schemas) = _createMockSchemas();
        uint256[] memory schemaIds = sp.registerBatch(uris, schemas);
        // Make two normal attestations
        Attestation[] memory attestations = _createMockAttestations(schemaIds);
        vm.prank(prankSender);
        uint256[] memory attestationIds = sp.attestBatch(attestations);
        string[] memory reasons = _createMockReasons();
        // Trigger `AttestationNonexistent`
        uint256 originalAttestationid = attestationIds[0];
        uint256 fakeAttestationId = 10000;
        attestationIds[0] = fakeAttestationId;
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, fakeAttestationId));
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons);
        attestationIds[0] = originalAttestationid;
        // Trigger `AttestationIrrevocable`
        vm.expectRevert(abi.encodeWithSelector(AttestationIrrevocable.selector, schemaIds[1], attestationIds[1]));
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons);
        // Trigger `AttestationWrongAttester`
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, address(this)));
        sp.revokeBatch(attestationIds, reasons);
    }

    function test_revoke() public {
        // Register 2 different schemas
        (SchemaMetadata[] memory uris, Schema[] memory schemas) = _createMockSchemas();
        schemas[1].revocable = true;
        uint256[] memory schemaIds = sp.registerBatch(uris, schemas);
        // Make two normal attestations
        Attestation[] memory attestations = _createMockAttestations(schemaIds);
        vm.prank(prankSender);
        uint256[] memory attestationIds = sp.attestBatch(attestations);
        string[] memory reasons = _createMockReasons();
        // Revoke normally
        vm.expectEmit();
        emit AttestationRevoked(attestationIds[0], reasons[0]);
        emit AttestationRevoked(attestationIds[1], reasons[1]);
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons);
        // Revoke again and trigger `AttestationAlreadyRevoked`
        vm.expectRevert(abi.encodeWithSelector(AttestationAlreadyRevoked.selector, attestationIds[0]));
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons);
    }

    function test_attestOffchain() public {
        string[] memory attestationIds = _createMockAttestationIds();
        // Attest normally
        vm.expectEmit();
        emit OffchainAttestationMade(attestationIds[0]);
        emit OffchainAttestationMade(attestationIds[1]);
        sp.attestOffchainBatch(attestationIds);
        // Attest again, trigger `OffchainAttestationExists`
        vm.expectRevert(abi.encodeWithSelector(OffchainAttestationExists.selector, attestationIds[0]));
        sp.attestOffchainBatch(attestationIds);
    }

    function test_revokeOffchain() public {
        string[] memory attestationIds = _createMockAttestationIds();
        string[] memory reasons = _createMockReasons();
        // Revoke, trigger `AttestationNonexistent`
        vm.expectRevert(abi.encodeWithSelector(OffchainAttestationNonexistent.selector, attestationIds[0]));
        sp.revokeOffchainBatch(attestationIds, reasons);
        // Attest normally
        vm.warp(2); // Set block.timestamp to 2 to revoke checks aren't incorrectly tripped
        sp.attestOffchainBatch(attestationIds);
        // Revoke normally
        vm.expectEmit();
        emit OffchainAttestationRevoked(attestationIds[0], reasons[0]);
        emit OffchainAttestationRevoked(attestationIds[1], reasons[1]);
        sp.revokeOffchainBatch(attestationIds, reasons);
    }

    function _createMockSchemas() internal view returns (SchemaMetadata[] memory, Schema[] memory) {
        Schema memory schema0 = Schema({
            revocable: true,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 0,
            resolver: mockResolver,
            schema: "stupid0"
        });
        Schema memory schema1 = Schema({
            revocable: false,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 100,
            resolver: mockResolver,
            schema: "stupid1"
        });
        SchemaMetadata[] memory uris = new SchemaMetadata[](2);
        uris[0] = SchemaMetadata({dataLocation: DataLocation.ARWEAVE, uri: "uri0"});
        uris[1] = SchemaMetadata({dataLocation: DataLocation.IPFS, uri: "uri1"});
        Schema[] memory schemas = new Schema[](2);
        schemas[0] = schema0;
        schemas[1] = schema1;
        return (uris, schemas);
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

    function _createMockAttestations(uint256[] memory schemaIds) internal view returns (Attestation[] memory) {
        Attestation memory attestation0 = Attestation({
            schemaId: schemaIds[0],
            linkedAttestationId: 0,
            data: "",
            attester: prankSender,
            validUntil: uint64(block.timestamp),
            revoked: false,
            recipients: _createMockRecipients()
        });
        Attestation memory attestation1 = Attestation({
            schemaId: schemaIds[1],
            linkedAttestationId: 0,
            data: "",
            attester: prankSender,
            validUntil: uint64(block.timestamp),
            revoked: false,
            recipients: _createMockRecipients()
        });
        Attestation[] memory attestations = new Attestation[](2);
        attestations[0] = attestation0;
        attestations[1] = attestation1;
        return attestations;
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
