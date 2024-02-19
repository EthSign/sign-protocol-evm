// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.20;

import { ISP } from "../interfaces/ISP.sol";
import { ISPHook } from "../interfaces/ISPHook.sol";
import { ISPGlobalHook } from "../interfaces/ISPGlobalHook.sol";
import { Schema } from "../models/Schema.sol";
import { Attestation, OffchainAttestation } from "../models/Attestation.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// solhint-disable var-name-mixedcase
contract SP is ISP, UUPSUpgradeable, OwnableUpgradeable {
    /// @custom:storage-location erc7201:ethsign.SP
    struct SPStorage {
        bool paused;
        mapping(uint64 => Schema) schemaRegistry;
        mapping(uint64 => Attestation) attestationRegistry;
        mapping(string => OffchainAttestation) offchainAttestationRegistry;
        uint64 schemaCounter;
        uint64 attestationCounter;
        uint64 initialSchemaCounter;
        uint64 initialAttestationCounter;
        ISPGlobalHook globalHook;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.SP")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SPStorageLocation = 0x9f5ee6fb062129ebe4f4f93ab4866ee289599fbb940712219d796d503e3bd400;

    bytes32 private constant REGISTER_ACTION_NAME = "REGISTER";
    bytes32 private constant REGISTER_BATCH_ACTION_NAME = "REGISTER_BATCH";
    bytes32 private constant ATTEST_ACTION_NAME = "ATTEST";
    bytes32 private constant ATTEST_BATCH_ACTION_NAME = "ATTEST_BATCH";
    bytes32 private constant ATTEST_OFFCHAIN_ACTION_NAME = "ATTEST_OFFCHAIN";
    bytes32 private constant ATTEST_OFFCHAIN_BATCH_ACTION_NAME = "ATTEST_OFFCHAIN_BATCH";
    bytes32 private constant REVOKE_ACTION_NAME = "REVOKE";
    bytes32 private constant REVOKE_BATCH_ACTION_NAME = "REVOKE_BATCH";
    bytes32 private constant REVOKE_OFFCHAIN_ACTION_NAME = "REVOKE_OFFCHAIN";
    bytes32 private constant REVOKE_OFFCHAIN_BATCH_ACTION_NAME = "REVOKE_OFFCHAIN_BATCH";

    function _getSPStorage() internal pure returns (SPStorage storage $) {
        assembly {
            $.slot := SPStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize(uint64 schemaCounter_, uint64 attestationCounter_) public initializer {
        SPStorage storage $ = _getSPStorage();
        __Ownable_init(_msgSender());
        $.schemaCounter = schemaCounter_;
        $.attestationCounter = attestationCounter_;
        $.initialSchemaCounter = schemaCounter_;
        $.initialAttestationCounter = attestationCounter_;
    }

    function setGlobalHook(address hook) external onlyOwner {
        _getSPStorage().globalHook = ISPGlobalHook(hook);
    }

    function setPause(bool paused) external onlyOwner {
        _getSPStorage().paused = paused;
    }

    function register(
        Schema memory schema,
        bytes calldata delegateSignature
    )
        external
        override
        returns (uint64 schemaId)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(schema.registrant, getDelegatedRegisterHash(schema), delegateSignature);
        } else {
            if (schema.registrant != _msgSender()) revert SchemaWrongRegistrant();
        }
        schemaId = _register(schema);
        _callGlobalHook();
    }

    function registerBatch(
        Schema[] calldata schemas,
        bytes calldata delegateSignature
    )
        external
        override
        returns (uint64[] memory schemaIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        address registrant = schemas[0].registrant;
        if (delegateMode) {
            // solhint-disable-next-line max-line-length
            __checkDelegationSignature(schemas[0].registrant, getDelegatedRegisterBatchHash(schemas), delegateSignature);
        } else {
            if (schemas[0].registrant != _msgSender()) {
                revert SchemaWrongRegistrant();
            }
        }
        schemaIds = new uint64[](schemas.length);
        for (uint256 i = 0; i < schemas.length; i++) {
            if (delegateMode && schemas[i].registrant != registrant) {
                revert SchemaWrongRegistrant();
            }
            schemaIds[i] = _register(schemas[i]);
        }
        _callGlobalHook();
    }

    function attest(
        Attestation calldata attestation,
        string calldata indexingKey,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        override
        returns (uint64)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(attestation.attester, getDelegatedAttestHash(attestation), delegateSignature);
        }
        (uint64 schemaId, uint64 attestationId) = _attest(attestation, indexingKey, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveAttestation(attestation.attester, schemaId, attestationId, extraData);
        }
        _callGlobalHook();
        return attestationId;
    }

    function attestBatch(
        Attestation[] memory attestations,
        string[] memory indexingKeys,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        override
        returns (uint64[] memory attestationIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        address attester = attestations[0].attester;
        if (delegateMode) {
            __checkDelegationSignature(attester, getDelegatedAttestBatchHash(attestations), delegateSignature);
        }
        attestationIds = new uint64[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            if (delegateMode && attestations[i].attester != attester) {
                revert AttestationWrongAttester();
            }
            (uint64 schemaId, uint64 attestationId) = _attest(attestations[i], indexingKeys[i], delegateMode);
            attestationIds[i] = attestationId;
            ISPHook hook = __getResolverFromAttestationId(attestationId);
            if (address(hook) != address(0)) {
                hook.didReceiveAttestation(attestations[i].attester, schemaId, attestationId, extraData);
            }
        }
        _callGlobalHook();
    }

    function attest(
        Attestation calldata attestation,
        uint256 resolverFeesETH,
        string calldata indexingKey,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        payable
        returns (uint64)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(attestation.attester, getDelegatedAttestHash(attestation), delegateSignature);
        }
        (uint64 schemaId, uint64 attestationId) = _attest(attestation, indexingKey, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveAttestation{ value: resolverFeesETH }(
                attestation.attester, schemaId, attestationId, extraData
            );
        }
        _callGlobalHook();
        return attestationId;
    }

    function attestBatch(
        Attestation[] memory attestations,
        uint256[] memory resolverFeesETH,
        string[] memory indexingKeys,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        payable
        override
        returns (uint64[] memory attestationIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        address attester = attestations[0].attester;
        if (delegateMode) {
            __checkDelegationSignature(attester, getDelegatedAttestBatchHash(attestations), delegateSignature);
        }
        attestationIds = new uint64[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            if (delegateMode && attestations[i].attester != attester) {
                revert AttestationWrongAttester();
            }
            (uint64 schemaId, uint64 attestationId) = _attest(attestations[i], indexingKeys[i], delegateMode);
            attestationIds[i] = attestationId;
            ISPHook hook = __getResolverFromAttestationId(attestationId);
            if (address(hook) != address(0)) {
                hook.didReceiveAttestation{ value: resolverFeesETH[i] }(
                    attestations[i].attester, schemaId, attestationId, extraData
                );
            }
        }
        _callGlobalHook();
    }

    function attest(
        Attestation memory attestation,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount,
        string memory indexingKey,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        override
        returns (uint64)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(attestation.attester, getDelegatedAttestHash(attestation), delegateSignature);
        }
        (uint64 schemaId, uint64 attestationId) = _attest(attestation, indexingKey, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveAttestation(
                attestation.attester,
                schemaId,
                attestationId,
                resolverFeesERC20Token,
                resolverFeesERC20Amount,
                extraData
            );
        }
        _callGlobalHook();
        return attestationId;
    }

    function attestBatch(
        Attestation[] memory attestations,
        IERC20[] memory resolverFeesERC20Tokens,
        uint256[] memory resolverFeesERC20Amount,
        string[] memory indexingKeys,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        override
        returns (uint64[] memory attestationIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        // address attester = attestations[0].attester;
        if (delegateMode) {
            __checkDelegationSignature(
                attestations[0].attester, getDelegatedAttestBatchHash(attestations), delegateSignature
            );
        }
        attestationIds = new uint64[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            if (delegateMode && attestations[i].attester != attestations[0].attester) {
                revert AttestationWrongAttester();
            }
            (uint64 schemaId, uint64 attestationId) = _attest(attestations[i], indexingKeys[i], delegateMode);
            attestationIds[i] = attestationId;
            ISPHook hook = __getResolverFromAttestationId(attestationId);
            if (address(hook) != address(0)) {
                hook.didReceiveAttestation(
                    attestations[i].attester,
                    schemaId,
                    attestationId,
                    resolverFeesERC20Tokens[i],
                    resolverFeesERC20Amount[i],
                    extraData
                );
            }
        }
        _callGlobalHook();
    }

    function attestOffchain(
        string calldata offchainAttestationId,
        address delegateAttester,
        bytes calldata delegateSignature
    )
        external
        override
    {
        address attester = _msgSender();
        if (delegateSignature.length != 0) {
            __checkDelegationSignature(
                delegateAttester, getDelegatedOffchainAttestHash(offchainAttestationId), delegateSignature
            );
            attester = delegateAttester;
        }
        _attestOffchain(offchainAttestationId, attester);
        _callGlobalHook();
    }

    function attestOffchainBatch(
        string[] calldata attestationIds,
        address delegateAttester,
        bytes calldata delegateSignature
    )
        external
        override
    {
        address attester = _msgSender();
        if (delegateSignature.length != 0) {
            __checkDelegationSignature(
                delegateAttester, getDelegatedOffchainAttestBatchHash(attestationIds), delegateSignature
            );
            attester = delegateAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i], attester);
        }
        _callGlobalHook();
    }

    function revoke(
        uint64 attestationId,
        string calldata reason,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        override
    {
        address storageAttester = _getSPStorage().attestationRegistry[attestationId].attester;
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(
                storageAttester, getDelegatedRevokeHash(attestationId, reason), delegateSignature
            );
        }
        uint64 schemaId = _revoke(attestationId, reason, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveRevocation(storageAttester, schemaId, attestationId, extraData);
        }
        _callGlobalHook();
    }

    function revokeBatch(
        uint64[] memory attestationIds,
        string[] memory reasons,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        override
    {
        address currentAttester = _msgSender();
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage().attestationRegistry[attestationIds[0]].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedRevokeBatchHash(attestationIds, reasons), delegateSignature
            );
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            address storageAttester = _getSPStorage().attestationRegistry[attestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester();
            }
            uint64 schemaId = _revoke(attestationIds[i], reasons[i], delegateMode);
            ISPHook hook = __getResolverFromAttestationId(attestationIds[i]);
            if (address(hook) != address(0)) {
                hook.didReceiveRevocation(storageAttester, schemaId, attestationIds[i], extraData);
            }
        }
        _callGlobalHook();
    }

    function revoke(
        uint64 attestationId,
        string memory reason,
        uint256 resolverFeesETH,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        payable
        override
    {
        address storageAttester = _getSPStorage().attestationRegistry[attestationId].attester;
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(
                storageAttester, getDelegatedRevokeHash(attestationId, reason), delegateSignature
            );
        }
        uint64 schemaId = _revoke(attestationId, reason, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveRevocation{ value: resolverFeesETH }(storageAttester, schemaId, attestationId, extraData);
        }
        _callGlobalHook();
    }

    function revokeBatch(
        uint64[] memory attestationIds,
        string[] memory reasons,
        uint256[] memory resolverFeesETH,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        payable
        override
    {
        address currentAttester = _msgSender();
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage().attestationRegistry[attestationIds[0]].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedRevokeBatchHash(attestationIds, reasons), delegateSignature
            );
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            address storageAttester = _getSPStorage().attestationRegistry[attestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester();
            }
            uint64 schemaId = _revoke(attestationIds[i], reasons[i], delegateMode);
            ISPHook hook = __getResolverFromAttestationId(attestationIds[i]);
            if (address(hook) != address(0)) {
                hook.didReceiveRevocation{ value: resolverFeesETH[i] }(
                    storageAttester, schemaId, attestationIds[i], extraData
                );
            }
        }
        _callGlobalHook();
    }

    function revoke(
        uint64 attestationId,
        string memory reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        override
    {
        address storageAttester = _getSPStorage().attestationRegistry[attestationId].attester;
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(
                storageAttester, getDelegatedRevokeHash(attestationId, reason), delegateSignature
            );
        }
        uint64 schemaId = _revoke(attestationId, reason, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveRevocation(
                storageAttester, schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount, extraData
            );
        }
        _callGlobalHook();
    }

    function revokeBatch(
        uint64[] memory attestationIds,
        string[] memory reasons,
        IERC20[] memory resolverFeesERC20Tokens,
        uint256[] memory resolverFeesERC20Amount,
        bytes memory delegateSignature,
        bytes memory extraData
    )
        external
        override
    {
        address currentAttester = _msgSender();
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage().attestationRegistry[attestationIds[0]].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedRevokeBatchHash(attestationIds, reasons), delegateSignature
            );
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            address storageAttester = _getSPStorage().attestationRegistry[attestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester();
            }
            uint64 schemaId = _revoke(attestationIds[i], reasons[i], delegateMode);
            ISPHook hook = __getResolverFromAttestationId(attestationIds[i]);
            if (address(hook) != address(0)) {
                hook.didReceiveRevocation(
                    storageAttester,
                    schemaId,
                    attestationIds[i],
                    resolverFeesERC20Tokens[i],
                    resolverFeesERC20Amount[i],
                    extraData
                );
            }
        }
        _callGlobalHook();
    }

    function revokeOffchain(
        string calldata offchainAttestationId,
        string calldata reason,
        bytes calldata delegateSignature
    )
        external
        override
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage().offchainAttestationRegistry[offchainAttestationId].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedOffchainRevokeHash(offchainAttestationId, reason), delegateSignature
            );
        }
        _revokeOffchain(offchainAttestationId, reason, delegateMode);
        _callGlobalHook();
    }

    function revokeOffchainBatch(
        string[] calldata offchainAttestationIds,
        string[] calldata reasons,
        bytes calldata delegateSignature
    )
        external
        override
    {
        address currentAttester = _msgSender();
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage().offchainAttestationRegistry[offchainAttestationIds[0]].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedOffchainRevokeBatchHash(offchainAttestationIds, reasons), delegateSignature
            );
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < offchainAttestationIds.length; i++) {
            address storageAttester = _getSPStorage().offchainAttestationRegistry[offchainAttestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester();
            }
            _revokeOffchain(offchainAttestationIds[i], reasons[i], delegateMode);
        }
        _callGlobalHook();
    }

    function getSchema(uint64 schemaId) external view override returns (Schema memory) {
        SPStorage storage $ = _getSPStorage();
        if (schemaId < $.initialSchemaCounter) revert LegacySPRequired();
        return $.schemaRegistry[schemaId];
    }

    function getAttestation(uint64 attestationId) external view override returns (Attestation memory) {
        SPStorage storage $ = _getSPStorage();
        if (attestationId < $.initialAttestationCounter) revert LegacySPRequired();
        return $.attestationRegistry[attestationId];
    }

    function getOffchainAttestation(string calldata offchainAttestationId)
        external
        view
        returns (OffchainAttestation memory)
    {
        return _getSPStorage().offchainAttestationRegistry[offchainAttestationId];
    }

    function schemaCounter() external view override returns (uint64) {
        return _getSPStorage().schemaCounter;
    }

    function attestationCounter() external view override returns (uint64) {
        return _getSPStorage().attestationCounter;
    }

    function version() external pure override returns (string memory) {
        return "1.1.1";
    }

    function getDelegatedRegisterHash(Schema memory schema) public pure override returns (bytes32) {
        return keccak256(abi.encode(REGISTER_ACTION_NAME, schema));
    }

    function getDelegatedRegisterBatchHash(Schema[] memory schemas) public pure override returns (bytes32) {
        return keccak256(abi.encode(REGISTER_ACTION_NAME, schemas));
    }

    function getDelegatedAttestHash(Attestation memory attestation) public pure override returns (bytes32) {
        return keccak256(abi.encode(ATTEST_ACTION_NAME, attestation));
    }

    function getDelegatedAttestBatchHash(Attestation[] memory attestations) public pure returns (bytes32) {
        return keccak256(abi.encode(ATTEST_BATCH_ACTION_NAME, attestations));
    }

    function getDelegatedOffchainAttestHash(string memory offchainAttestationId)
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(ATTEST_OFFCHAIN_ACTION_NAME, offchainAttestationId));
    }

    function getDelegatedOffchainAttestBatchHash(string[] memory offchainAttestationIds)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(ATTEST_OFFCHAIN_BATCH_ACTION_NAME, offchainAttestationIds));
    }

    function getDelegatedRevokeHash(
        uint64 attestationId,
        string memory reason
    )
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOKE_ACTION_NAME, attestationId, reason));
    }

    function getDelegatedRevokeBatchHash(
        uint64[] memory attestationIds,
        string[] memory reasons
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOKE_BATCH_ACTION_NAME, attestationIds, reasons));
    }

    function getDelegatedOffchainRevokeHash(
        string memory offchainAttestationId,
        string memory reason
    )
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOKE_OFFCHAIN_ACTION_NAME, offchainAttestationId, reason));
    }

    function getDelegatedOffchainRevokeBatchHash(
        string[] memory offchainAttestationIds,
        string[] memory reasons
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOKE_OFFCHAIN_BATCH_ACTION_NAME, offchainAttestationIds, reasons));
    }

    function _callGlobalHook() internal {
        SPStorage storage $ = _getSPStorage();
        if (address($.globalHook) != address(0)) $.globalHook.callHook(_msgData(), _msgSender());
    }

    function _register(Schema memory schema) internal returns (uint64 schemaId) {
        SPStorage storage $ = _getSPStorage();
        if ($.paused) revert Paused();
        schemaId = $.schemaCounter++;
        schema.timestamp = uint64(block.timestamp);
        $.schemaRegistry[schemaId] = schema;
        emit SchemaRegistered(schemaId);
    }

    function _attest(
        Attestation memory attestation,
        string memory indexingKey,
        bool delegateMode
    )
        internal
        returns (uint64 schemaId, uint64 attestationId)
    {
        SPStorage storage $ = _getSPStorage();
        if ($.paused) revert Paused();
        attestationId = $.attestationCounter++;
        attestation.attestTimestamp = uint64(block.timestamp);
        attestation.revokeTimestamp = 0;
        // In delegation mode, the attester is already checked ahead of time.
        if (!delegateMode && attestation.attester != _msgSender()) {
            revert AttestationWrongAttester();
        }
        if (attestation.linkedAttestationId > 0 && !__attestationExists(attestation.linkedAttestationId)) {
            revert AttestationNonexistent();
        }
        if (
            attestation.linkedAttestationId != 0
                && $.attestationRegistry[attestation.linkedAttestationId].attester != _msgSender()
        ) {
            revert AttestationWrongAttester();
        }
        Schema memory s = $.schemaRegistry[attestation.schemaId];
        if (!__schemaExists(attestation.schemaId)) revert SchemaNonexistent();
        if (s.maxValidFor > 0) {
            uint256 attestationValidFor = attestation.validUntil - block.timestamp;
            if (s.maxValidFor < attestationValidFor) {
                revert AttestationInvalidDuration();
            }
        }
        $.attestationRegistry[attestationId] = attestation;
        emit AttestationMade(attestationId, indexingKey);
        return (attestation.schemaId, attestationId);
    }

    function _attestOffchain(string calldata offchainAttestationId, address attester) internal {
        SPStorage storage $ = _getSPStorage();
        if ($.paused) revert Paused();
        OffchainAttestation storage attestation = $.offchainAttestationRegistry[offchainAttestationId];
        if (__offchainAttestationExists(offchainAttestationId)) {
            revert OffchainAttestationExists();
        }
        attestation.timestamp = uint64(block.timestamp);
        attestation.attester = attester;
        emit OffchainAttestationMade(offchainAttestationId);
    }

    function _revoke(
        uint64 attestationId,
        string memory reason,
        bool delegateMode
    )
        internal
        returns (uint64 schemaId)
    {
        SPStorage storage $ = _getSPStorage();
        if ($.paused) revert Paused();
        Attestation storage a = $.attestationRegistry[attestationId];
        if (a.attester == address(0)) revert AttestationNonexistent();
        // In delegation mode, the attester is already checked ahead of time.
        if (!delegateMode && a.attester != _msgSender()) revert AttestationWrongAttester();
        Schema memory s = $.schemaRegistry[a.schemaId];
        if (!s.revocable) revert AttestationIrrevocable();
        if (a.revoked) revert AttestationAlreadyRevoked();
        a.revoked = true;
        a.revokeTimestamp = uint64(block.timestamp);
        emit AttestationRevoked(attestationId, reason);
        return a.schemaId;
    }

    function _revokeOffchain(
        string calldata offchainAttestationId,
        string calldata reason,
        bool delegateMode
    )
        internal
    {
        SPStorage storage $ = _getSPStorage();
        if ($.paused) revert Paused();
        OffchainAttestation storage attestation = $.offchainAttestationRegistry[offchainAttestationId];
        if (!__offchainAttestationExists(offchainAttestationId)) {
            revert OffchainAttestationNonexistent();
        }
        if (!delegateMode && attestation.attester != _msgSender()) {
            revert AttestationWrongAttester();
        }
        if (attestation.timestamp == 1) {
            revert OffchainAttestationAlreadyRevoked();
        }
        attestation.timestamp = 1;
        emit OffchainAttestationRevoked(offchainAttestationId, reason);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }

    function __checkDelegationSignature(
        address delegateAttester,
        bytes32 hash,
        bytes memory delegateSignature
    )
        internal
        view
    {
        if (
            !SignatureChecker.isValidSignatureNow(
                delegateAttester, MessageHashUtils.toEthSignedMessageHash(hash), delegateSignature
            )
        ) {
            revert InvalidDelegateSignature();
        }
    }

    function __getResolverFromAttestationId(uint64 attestationId) internal view returns (ISPHook) {
        SPStorage storage $ = _getSPStorage();
        Attestation memory a = $.attestationRegistry[attestationId];
        Schema memory s = $.schemaRegistry[a.schemaId];
        return s.hook;
    }

    function __schemaExists(uint64 schemaId) internal view returns (bool) {
        return _getSPStorage().schemaRegistry[schemaId].timestamp > 0;
    }

    function __attestationExists(uint64 attestationId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return attestationId < $.attestationCounter;
    }

    function __offchainAttestationExists(string memory attestationId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return $.offchainAttestationRegistry[attestationId].timestamp != 0;
    }
}
