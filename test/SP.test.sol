// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// solhint-disable no-global-import
// solhint-disable no-console
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import { SP } from "../src/core/SP.sol";
import { ISP } from "../src/interfaces/ISP.sol";
import { MockResolver } from "../src/mock/MockResolver.sol";
import { Schema } from "../src/models/Schema.sol";
import { DataLocation } from "../src/models/DataLocation.sol";
import { Attestation, OffchainAttestation } from "../src/models/Attestation.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SPTest is Test {
    ISP public sp;
    MockResolver public mockResolver;
    address public prankSender = 0x55D22d83752a9bE59B8959f97FCf3b2CAbca5094;
    address public prankRecipient0 = 0x003BBE6Da0EB4963856395829030FcE383a14C53;
    address public prankRecipient1 = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    event SchemaRegistered(uint64 schemaId);
    event AttestationMade(uint64 attestationId, string indexingKey);
    event AttestationRevoked(uint64 attestationId, string reason);
    event OffchainAttestationMade(string attestationId);
    event OffchainAttestationRevoked(string attestationId, string reason);

    error SchemaNonexistent(uint64 nonexistentSchemaId);
    error SchemaWrongRegistrant(address expected, address actual);
    error AttestationIrrevocable(uint64 schemaId, uint64 offendingAttestationId);
    error AttestationNonexistent(uint64 nonexistentAttestationId);
    error AttestationInvalidDuration(uint64 offendingAttestationId, uint64 maxDuration, uint64 inputDuration);
    error AttestationAlreadyRevoked(uint64 offendingAttestationId);
    error AttestationWrongAttester(address expected, address actual);
    error OffchainAttestationExists(string existingOffchainAttestationId);
    error OffchainAttestationNonexistent(string nonexistentOffchainAttestationId);
    error OffchainAttestationAlreadyRevoked(string offendingOffchainAttestationId);
    error InvalidDelegateSignature();

    function setUp() public {
        sp = new SP();
        SP(address(sp)).initialize(1, 1);
        mockResolver = new MockResolver();
    }

    // NON DELEGATED TEST CASES

    function test_register() public {
        Schema[] memory schemas = _createMockSchemas();
        // Register 2 different schemas, check events & storage
        uint64 currentSchemaCounter = sp.schemaCounter();
        vm.expectEmit();
        emit SchemaRegistered(currentSchemaCounter++);
        emit SchemaRegistered(currentSchemaCounter++);
        uint64 mockTimestamp = 12_345;
        vm.warp(mockTimestamp);
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        Schema memory schema0Expected = schemas[0];
        Schema memory schema1Expected = schemas[1];
        Schema memory schema0Actual = sp.getSchema(schemaIds[0]);
        Schema memory schema1Actual = sp.getSchema(schemaIds[1]);
        assertEq(schema0Expected.data, schema0Actual.data);
        assertEq(schema0Expected.revocable, schema0Actual.revocable);
        assertEq(address(schema0Expected.hook), address(schema0Actual.hook));
        assertEq(schema0Expected.maxValidFor, schema0Actual.maxValidFor);
        assertEq(mockTimestamp, schema0Actual.timestamp);
        assertEq(schema1Expected.data, schema1Actual.data);
        assertEq(schema1Expected.revocable, schema1Actual.revocable);
        assertEq(address(schema1Expected.hook), address(schema1Actual.hook));
        assertEq(schema1Expected.maxValidFor, schema1Actual.maxValidFor);
        assertEq(mockTimestamp, schema1Actual.timestamp);
    }

    function test_attest() public {
        uint64 mockTimestamp = 12_345;
        vm.warp(mockTimestamp);
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        // Create two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        // Modify the second one to trigger `AttestationInvalidDuration`
        uint64 attestationId0 = sp.attestationCounter();
        attestations[1].validUntil = uint64(mockTimestamp + attestations[1].validUntil + schemas[1].maxValidFor + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                AttestationInvalidDuration.selector,
                attestationId0 + 1,
                schemas[1].maxValidFor,
                attestations[1].validUntil - block.timestamp
            )
        );
        vm.prank(prankSender);
        sp.attestBatch(attestations, indexingKeys, "", "");
        // Reset and trigger `SchemaNonexistent`
        (attestations,) = _createMockAttestations(schemaIds);
        attestations[1].schemaId = 100_000;
        vm.expectRevert(abi.encodeWithSelector(SchemaNonexistent.selector, attestations[1].schemaId));
        vm.prank(prankSender);
        sp.attestBatch(attestations, indexingKeys, "", "");
        // Reset and trigger `AttestationNonexistent` for a linked attestation
        (attestations,) = _createMockAttestations(schemaIds);
        uint64 nonexistentAttestationId = 100_000;
        attestations[1].linkedAttestationId = nonexistentAttestationId;
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, nonexistentAttestationId));
        vm.prank(prankSender);
        sp.attestBatch(attestations, indexingKeys, "", "");
        // Reset and trigger `AttestationWrongAttester` for a linked attestation
        (attestations,) = _createMockAttestations(schemaIds);
        attestations[1].attester = prankRecipient0;
        attestations[1].linkedAttestationId = attestationId0;
        vm.expectEmit();
        emit AttestationMade(attestationId0, indexingKeys[0]);
        vm.prank(prankSender);
        sp.attest(attestations[0], indexingKeys[0], "", "");
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, prankRecipient0));
        vm.prank(prankRecipient0);
        sp.attest(attestations[1], indexingKeys[1], "", "");
        // Reset and make attest normally
        (attestations,) = _createMockAttestations(schemaIds);
        attestations[1].linkedAttestationId = attestationId0;
        vm.expectEmit();
        emit AttestationMade(attestationId0 + 1, indexingKeys[1]);
        vm.prank(prankSender);
        sp.attest(attestations[1], indexingKeys[1], "", "");
        // Check storage
        Attestation memory attestation0Actual = sp.getAttestation(attestationId0);
        Attestation memory attestation1Actual = sp.getAttestation(attestationId0 + 1);
        assertEq(attestation0Actual.attester, prankSender);
        assertEq(attestation0Actual.schemaId, attestations[0].schemaId);
        assertEq(attestation0Actual.attestTimestamp, mockTimestamp);
        assertEq(attestation0Actual.revokeTimestamp, 0);
        assertEq(attestation1Actual.attester, prankSender);
        assertEq(attestation1Actual.schemaId, attestations[1].schemaId);
        assertEq(attestation1Actual.attestTimestamp, mockTimestamp);
        assertEq(attestation1Actual.revokeTimestamp, 0);
    }

    function test_revokeFail() public {
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        // Make two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        vm.prank(prankSender);
        uint64[] memory attestationIds = sp.attestBatch(attestations, indexingKeys, "", "");
        string[] memory reasons = _createMockReasons();
        // Trigger `AttestationNonexistent`
        uint64 originalAttestationid = attestationIds[0];
        uint64 fakeAttestationId = 10_000;
        attestationIds[0] = fakeAttestationId;
        vm.expectRevert(abi.encodeWithSelector(AttestationNonexistent.selector, fakeAttestationId));
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons, "", "");
        attestationIds[0] = originalAttestationid;
        // Trigger `AttestationIrrevocable`
        vm.expectRevert(abi.encodeWithSelector(AttestationIrrevocable.selector, schemaIds[1], attestationIds[1]));
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons, "", "");
        // Trigger `AttestationWrongAttester`
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, address(this)));
        sp.revokeBatch(attestationIds, reasons, "", "");
    }

    function test_revoke() public {
        uint64 mockTimestamp = 12_345;
        vm.warp(mockTimestamp);
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        schemas[1].revocable = true;
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        // Make two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        vm.prank(prankSender);
        uint64[] memory attestationIds = sp.attestBatch(attestations, indexingKeys, "", "");
        string[] memory reasons = _createMockReasons();
        // Revoke normally
        vm.expectEmit();
        emit AttestationRevoked(attestationIds[0], reasons[0]);
        emit AttestationRevoked(attestationIds[1], reasons[1]);
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons, "", "");
        assertEq(sp.getAttestation(attestationIds[0]).revokeTimestamp, mockTimestamp);
        // Revoke again and trigger `AttestationAlreadyRevoked`
        vm.expectRevert(abi.encodeWithSelector(AttestationAlreadyRevoked.selector, attestationIds[0]));
        vm.prank(prankSender);
        sp.revokeBatch(attestationIds, reasons, "", "");
    }

    function test_attestOffchain() public {
        string[] memory attestationIds = _createMockAttestationIds();
        // Attest normally
        vm.expectEmit();
        emit OffchainAttestationMade(attestationIds[0]);
        emit OffchainAttestationMade(attestationIds[1]);
        sp.attestOffchainBatch(attestationIds, address(0), "");
        // Attest again, trigger `OffchainAttestationExists`
        vm.expectRevert(abi.encodeWithSelector(OffchainAttestationExists.selector, attestationIds[0]));
        sp.attestOffchainBatch(attestationIds, address(0), "");
    }

    function test_revokeOffchain() public {
        string[] memory attestationIds = _createMockAttestationIds();
        string[] memory reasons = _createMockReasons();
        // Revoke, trigger `AttestationNonexistent`
        vm.expectRevert(abi.encodeWithSelector(OffchainAttestationNonexistent.selector, attestationIds[0]));
        sp.revokeOffchainBatch(attestationIds, reasons, "");
        // Attest normally
        vm.prank(prankSender);
        vm.warp(2); // Set block.timestamp to 2 to revoke checks aren't incorrectly tripped
        sp.attestOffchainBatch(attestationIds, address(0), "");
        // Revoke, trigger `AttestationWrongAttester`
        vm.prank(prankRecipient0);
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, prankRecipient0));
        sp.revokeOffchainBatch(attestationIds, reasons, "");
        // Revoke normally
        vm.prank(prankSender);
        vm.expectEmit();
        emit OffchainAttestationRevoked(attestationIds[0], reasons[0]);
        emit OffchainAttestationRevoked(attestationIds[1], reasons[1]);
        sp.revokeOffchainBatch(attestationIds, reasons, "");
        // Revoke again, trigger `OffchainAttestationAlreadyRevoked`
        vm.prank(prankSender);
        vm.expectRevert(abi.encodeWithSelector(OffchainAttestationAlreadyRevoked.selector, attestationIds[0]));
        sp.revokeOffchainBatch(attestationIds, reasons, "");
    }

    // DELEGATED TEST CASES

    function test_register_delegated() public {
        (address signer, uint256 signerPk) = makeAddrAndKey("registrant");
        Schema[] memory schemas = _createMockSchemas();
        schemas[0].registrant = signer;
        bytes32 hash = sp.getDelegatedRegisterHash(schemas[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.expectRevert(abi.encodeWithSelector(SchemaWrongRegistrant.selector, signer, address(this)));
        sp.register(schemas[0], "");
        sp.register(schemas[0], _vrsToSignature(v, r, s));
    }

    function test_register_batch_delegated() public {
        (address signer, uint256 signerPk) = makeAddrAndKey("registrant");
        Schema[] memory schemas = _createMockSchemas();
        schemas[0].registrant = signer;
        schemas[1].registrant = signer;
        bytes32 hash = sp.getDelegatedRegisterBatchHash(schemas);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.expectRevert(abi.encodeWithSelector(SchemaWrongRegistrant.selector, signer, address(this)));
        sp.registerBatch(schemas, "");
        sp.registerBatch(schemas, _vrsToSignature(v, r, s));
    }

    function test_attest_delegated() public {
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        uint64 attestationId0 = sp.attestationCounter();
        // Create two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        // Create ECDSA signature
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        attestations[0].attester = signer;
        bytes32 hash = sp.getDelegatedAttestHash(attestations[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        // Delegate attest batch
        sp.attest(attestations[0], indexingKeys[0], _vrsToSignature(v, r, s), "");
        Attestation memory attestation0Actual = sp.getAttestation(attestationId0);
        assertEq(attestation0Actual.attester, signer);
        // Alter attestation after generating signature, should fail signature check
        attestations[0].attester = prankSender;
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.attestBatch(attestations, indexingKeys, _vrsToSignature(v, r, s), "");
        attestations[0].attester = signer;
        // Try to make signer sign for someone else, should fail checks
        // Altering the first reference attester, should revert with `InvalidDelegateSignature`
        attestations[0].attester = prankSender;
        hash = sp.getDelegatedAttestBatchHash(attestations);
        (v, r, s) = vm.sign(signerPk, hash);
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.attest(attestations[0], indexingKeys[0], _vrsToSignature(v, r, s), "");
    }

    function test_attest_batch_delegated() public {
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        uint64 attestationId0 = sp.attestationCounter();
        // Create two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        // Create ECDSA signature
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        attestations[0].attester = signer;
        attestations[1].attester = signer;
        bytes32 hash = sp.getDelegatedAttestBatchHash(attestations);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        // Delegate attest batch
        sp.attestBatch(attestations, indexingKeys, _vrsToSignature(v, r, s), "");
        Attestation memory attestation0Actual = sp.getAttestation(attestationId0);
        Attestation memory attestation1Actual = sp.getAttestation(attestationId0 + 1);
        assertEq(attestation0Actual.attester, signer);
        assertEq(attestation1Actual.attester, signer);
        // Alter attestation after generating signature, should fail signature check
        attestations[1].attester = prankSender;
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.attestBatch(attestations, indexingKeys, _vrsToSignature(v, r, s), "");
        attestations[1].attester = signer;
        // Try to make signer sign for someone else, should fail checks
        // Altering the first reference attester, should revert with `InvalidDelegateSignature`
        attestations[0].attester = prankSender;
        hash = sp.getDelegatedAttestBatchHash(attestations);
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.attestBatch(attestations, indexingKeys, _vrsToSignature(v, r, s), "");
        attestations[0].attester = signer;
        // Altering the second attester, should fail attester consistency check
        attestations[1].attester = prankSender;
        hash = sp.getDelegatedAttestBatchHash(attestations);
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, signer, prankSender));
        sp.attestBatch(attestations, indexingKeys, _vrsToSignature(v, r, s), "");
    }

    function test_attest_offchain_delegated() public {
        string[] memory offchainAttestationIds = _createMockAttestationIds();
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        bytes32 hash = sp.getDelegatedOffchainAttestHash(offchainAttestationIds[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.attestOffchain(offchainAttestationIds[0], signer, _vrsToSignature(v, r, s));
        OffchainAttestation memory offchainAttestation = sp.getOffchainAttestation(offchainAttestationIds[0]);
        assertEq(offchainAttestation.attester, signer);
        // Try to fail on purpose
        hash = sp.getDelegatedOffchainAttestHash(offchainAttestationIds[0]);
        (v, r, s) = vm.sign(signerPk, hash);
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.attestOffchain(offchainAttestationIds[1], prankSender, _vrsToSignature(v, r, s));
    }

    function test_attest_offchain_batch_delegated() public {
        string[] memory offchainAttestationIds = _createMockAttestationIds();
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        bytes32 hash = sp.getDelegatedOffchainAttestBatchHash(offchainAttestationIds);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        // Try to fail on purpose first
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.attestOffchainBatch(offchainAttestationIds, prankSender, _vrsToSignature(v, r, s));
        // Attesting correctly
        sp.attestOffchainBatch(offchainAttestationIds, signer, _vrsToSignature(v, r, s));
        OffchainAttestation memory offchainAttestation = sp.getOffchainAttestation(offchainAttestationIds[0]);
        assertEq(offchainAttestation.attester, signer);
    }

    function test_revoke_delegated() public {
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        uint64 attestationId0 = sp.attestationCounter();
        // Create two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        // Delegate attest normally
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        attestations[0].attester = signer;
        bytes32 hash = sp.getDelegatedAttestHash(attestations[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.attest(attestations[0], indexingKeys[0], _vrsToSignature(v, r, s), "");
        // Delegated revoke
        // Try to fail on purpose first
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.revoke(attestationId0, "", _vrsToSignature(v, r, s), ""); // Still using the attest signature
        // Revoke correctly
        string memory reason = "reason";
        hash = sp.getDelegatedRevokeHash(attestationId0, reason);
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.revoke(attestationId0, reason, _vrsToSignature(v, r, s), "");
    }

    function test_revoke_batch_delegated() public {
        // Register 2 different schemas
        Schema[] memory schemas = _createMockSchemas();
        schemas[1].revocable = true;
        uint64[] memory schemaIds = sp.registerBatch(schemas, "");
        uint64[] memory attestationIds = new uint64[](2);
        attestationIds[0] = sp.attestationCounter();
        attestationIds[1] = attestationIds[0] + 1;
        // Create two normal attestations
        (Attestation[] memory attestations, string[] memory indexingKeys) = _createMockAttestations(schemaIds);
        // Delegate attest normally
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        attestations[0].attester = signer;
        attestations[1].attester = signer;
        bytes32 hash = sp.getDelegatedAttestBatchHash(attestations);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.attestBatch(attestations, indexingKeys, _vrsToSignature(v, r, s), "");
        // Revoke batch
        // Sign using the wrong signer first
        string[] memory reasons = _createMockReasons();
        (, uint256 signerPk1) = makeAddrAndKey("signer1");
        hash = sp.getDelegatedRevokeBatchHash(attestationIds, reasons);
        (v, r, s) = vm.sign(signerPk1, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.revokeBatch(attestationIds, _createMockReasons(), _vrsToSignature(v, r, s), "");
        // Revoke correctly with the correct signer
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.revokeBatch(attestationIds, _createMockReasons(), _vrsToSignature(v, r, s), "");
    }

    function test_revoke_offchain_delegated() public {
        string[] memory offchainAttestationIds = _createMockAttestationIds();
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        bytes32 hash = sp.getDelegatedOffchainAttestHash(offchainAttestationIds[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.warp(100);
        sp.attestOffchain(offchainAttestationIds[0], signer, _vrsToSignature(v, r, s));
        // Try to fail on purpose first
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.revokeOffchain(offchainAttestationIds[0], "", _vrsToSignature(v, r, s));
        // Revoke correctly
        string memory reason = "reason";
        hash = sp.getDelegatedOffchainRevokeHash(offchainAttestationIds[0], reason);
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.revokeOffchain(offchainAttestationIds[0], reason, _vrsToSignature(v, r, s));
    }

    function test_revoke_offchain_batch_delegated() public {
        string[] memory offchainAttestationIds = _createMockAttestationIds();
        (address signer, uint256 signerPk) = makeAddrAndKey("signer");
        bytes32 hash = sp.getDelegatedOffchainAttestBatchHash(offchainAttestationIds);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.warp(100);
        sp.attestOffchainBatch(offchainAttestationIds, signer, _vrsToSignature(v, r, s));
        vm.prank(prankSender);
        string memory offchainAttestationIdPranked = "prank";
        sp.attestOffchain(offchainAttestationIdPranked, address(0), "");
        string[] memory reasons = _createMockReasons();
        // Try to fail on purpose first
        vm.expectRevert(abi.encodeWithSelector(InvalidDelegateSignature.selector));
        sp.revokeOffchainBatch(offchainAttestationIds, _createMockReasons(), _vrsToSignature(v, r, s));
        // Make sure the signer cannot revoke someone else's attestation
        string memory offchainAttestationId1 = offchainAttestationIds[1];
        offchainAttestationIds[1] = offchainAttestationIdPranked;
        hash = sp.getDelegatedOffchainRevokeBatchHash(offchainAttestationIds, reasons);
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        vm.expectRevert(abi.encodeWithSelector(AttestationWrongAttester.selector, prankSender, signer));
        sp.revokeOffchainBatch(offchainAttestationIds, _createMockReasons(), _vrsToSignature(v, r, s));
        // Revoke correctly
        offchainAttestationIds[1] = offchainAttestationId1;
        hash = sp.getDelegatedOffchainRevokeBatchHash(offchainAttestationIds, reasons);
        (v, r, s) = vm.sign(signerPk, MessageHashUtils.toEthSignedMessageHash(hash));
        sp.revokeOffchainBatch(offchainAttestationIds, _createMockReasons(), _vrsToSignature(v, r, s));
    }

    function _createMockSchemas() internal view returns (Schema[] memory) {
        Schema memory schema0 = Schema({
            registrant: address(this),
            revocable: true,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 0,
            hook: mockResolver,
            timestamp: 0,
            data: "stupid0"
        });
        Schema memory schema1 = Schema({
            registrant: address(this),
            revocable: false,
            dataLocation: DataLocation.ONCHAIN,
            maxValidFor: 100,
            hook: mockResolver,
            timestamp: 0,
            data: "stupid1"
        });
        Schema[] memory schemas = new Schema[](2);
        schemas[0] = schema0;
        schemas[1] = schema1;
        return schemas;
    }

    function _createMockRecipient() internal view returns (address[] memory) {
        address[] memory addresses = new address[](1);
        addresses[0] = prankRecipient0;
        return addresses;
    }

    function _createMockRecipients() internal view returns (bytes[] memory) {
        bytes[] memory addresses = new bytes[](2);
        addresses[0] = abi.encode(prankRecipient0);
        addresses[1] = abi.encode(prankRecipient1);
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

    function _createMockAttestations(uint64[] memory schemaIds)
        internal
        view
        returns (Attestation[] memory, string[] memory)
    {
        Attestation memory attestation0 = Attestation({
            schemaId: schemaIds[0],
            linkedAttestationId: 0,
            attestTimestamp: 0,
            revokeTimestamp: 0,
            data: "",
            attester: prankSender,
            validUntil: uint64(block.timestamp),
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: _createMockRecipients()
        });
        Attestation memory attestation1 = Attestation({
            schemaId: schemaIds[1],
            linkedAttestationId: 0,
            attestTimestamp: 0,
            revokeTimestamp: 0,
            data: "",
            attester: prankSender,
            validUntil: uint64(block.timestamp),
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: _createMockRecipients()
        });
        Attestation[] memory attestations = new Attestation[](2);
        attestations[0] = attestation0;
        attestations[1] = attestation1;
        string[] memory indexingKeys = new string[](2);
        indexingKeys[0] = "test indexing key 0";
        indexingKeys[1] = "test indexing key 1";
        return (attestations, indexingKeys);
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

    function _vrsToSignature(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes memory) {
        return abi.encodePacked(r, s, v);
    }
}
