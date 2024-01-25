// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.20;

import { ISP } from "../interfaces/ISP.sol";
import { ISPHook } from "../interfaces/ISPHook.sol";
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
        mapping(uint256 => Schema) _schemaRegistry;
        mapping(uint256 => Attestation) _attestationRegistry;
        mapping(string => OffchainAttestation) _offchainAttestationRegistry;
        uint256 schemaCounter;
        uint256 attestationCounter;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.SP")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SPStorageLocation = 0x9f5ee6fb062129ebe4f4f93ab4866ee289599fbb940712219d796d503e3bd400;

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
        if (block.chainid == 7001) {
            initialize(); // Special case for ZetaChain, where Foundry scripting fails
        }
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize() public initializer {
        SPStorage storage $ = _getSPStorage();
        __Ownable_init(_msgSender());
        $.schemaCounter = 1;
        $.attestationCounter = 1;
    }

    function register(Schema calldata schema) external override returns (uint256 schemaId) {
        return _register(schema);
    }

    function registerBatch(Schema[] calldata schemas) external override returns (uint256[] memory schemaIds) {
        schemaIds = new uint256[](schemas.length);
        for (uint256 i = 0; i < schemas.length; i++) {
            schemaIds[i] = _register(schemas[i]);
        }
    }

    function attest(
        Attestation calldata attestation,
        string calldata indexingKey,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        override
        returns (uint256)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(attestation.attester, getDelegatedAttestHash(attestation), delegateSignature);
        }
        (uint256 schemaId, uint256 attestationId) = _attest(attestation, indexingKey, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) hook.didReceiveAttestation(_msgSender(), schemaId, attestationId, extraData);
        return attestationId;
    }

    function attestBatch(
        Attestation[] calldata attestations,
        string[] calldata indexingKeys,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        override
        returns (uint256[] memory attestationIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        address attester = attestations[0].attester;
        if (delegateMode) {
            __checkDelegationSignature(attester, getDelegatedAttestBatchHash(attestations), delegateSignature);
        }
        attestationIds = new uint256[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            if (delegateMode && attestations[i].attester != attester) {
                revert AttestationWrongAttester(attester, attestations[i].attester);
            }
            (uint256 schemaId, uint256 attestationId) = _attest(attestations[i], indexingKeys[i], delegateMode);
            attestationIds[i] = attestationId;
            ISPHook hook = __getResolverFromAttestationId(attestationId);
            if (address(hook) != address(0)) {
                hook.didReceiveAttestation(_msgSender(), schemaId, attestationId, extraData);
            }
        }
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
        returns (uint256)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(attestation.attester, getDelegatedAttestHash(attestation), delegateSignature);
        }
        (uint256 schemaId, uint256 attestationId) = _attest(attestation, indexingKey, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveAttestation{ value: resolverFeesETH }(_msgSender(), schemaId, attestationId, extraData);
        }
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
        returns (uint256[] memory attestationIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        address attester = attestations[0].attester;
        if (delegateMode) {
            __checkDelegationSignature(attester, getDelegatedAttestBatchHash(attestations), delegateSignature);
        }
        attestationIds = new uint256[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            if (delegateMode && attestations[i].attester != attester) {
                revert AttestationWrongAttester(attester, attestations[i].attester);
            }
            (uint256 schemaId, uint256 attestationId) = _attest(attestations[i], indexingKeys[i], delegateMode);
            attestationIds[i] = attestationId;
            ISPHook hook = __getResolverFromAttestationId(attestationId);
            if (address(hook) != address(0)) {
                hook.didReceiveAttestation{ value: resolverFeesETH[i] }(
                    _msgSender(), schemaId, attestationId, extraData
                );
            }
        }
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
        returns (uint256)
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(attestation.attester, getDelegatedAttestHash(attestation), delegateSignature);
        }
        (uint256 schemaId, uint256 attestationId) = _attest(attestation, indexingKey, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveAttestation(
                _msgSender(), schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount, extraData
            );
        }
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
        returns (uint256[] memory attestationIds)
    {
        bool delegateMode = delegateSignature.length != 0;
        // address attester = attestations[0].attester;
        if (delegateMode) {
            __checkDelegationSignature(
                attestations[0].attester, getDelegatedAttestBatchHash(attestations), delegateSignature
            );
        }
        attestationIds = new uint256[](attestations.length);
        for (uint256 i = 0; i < attestations.length; i++) {
            if (delegateMode && attestations[i].attester != attestations[0].attester) {
                revert AttestationWrongAttester(attestations[0].attester, attestations[i].attester);
            }
            (uint256 schemaId, uint256 attestationId) = _attest(attestations[i], indexingKeys[i], delegateMode);
            attestationIds[i] = attestationId;
            ISPHook hook = __getResolverFromAttestationId(attestationId);
            if (address(hook) != address(0)) {
                hook.didReceiveAttestation(
                    _msgSender(),
                    schemaId,
                    attestationId,
                    resolverFeesERC20Tokens[i],
                    resolverFeesERC20Amount[i],
                    extraData
                );
            }
        }
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
    }

    function revoke(
        uint256 attestationId,
        string calldata reason,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        override
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            __checkDelegationSignature(
                _getSPStorage()._attestationRegistry[attestationId].attester,
                getDelegatedRevokeHash(attestationId),
                delegateSignature
            );
        }
        uint256 schemaId = _revoke(attestationId, reason, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveRevocation(_msgSender(), schemaId, attestationId, extraData);
        }
    }

    function revokeBatch(
        uint256[] memory attestationIds,
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
            address storageAttester = _getSPStorage()._attestationRegistry[attestationIds[0]].attester;
            __checkDelegationSignature(storageAttester, getDelegatedRevokeBatchHash(attestationIds), delegateSignature);
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            address storageAttester = _getSPStorage()._attestationRegistry[attestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester(storageAttester, currentAttester);
            }
            uint256 schemaId = _revoke(attestationIds[i], reasons[i], delegateMode);
            ISPHook hook = __getResolverFromAttestationId(attestationIds[i]);
            if (address(hook) != address(0)) {
                hook.didReceiveRevocation(_msgSender(), schemaId, attestationIds[i], extraData);
            }
        }
    }

    function revoke(
        uint256 attestationId,
        string calldata reason,
        uint256 resolverFeesETH,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        payable
        override
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage()._attestationRegistry[attestationId].attester;
            __checkDelegationSignature(storageAttester, getDelegatedRevokeHash(attestationId), delegateSignature);
        }
        uint256 schemaId = _revoke(attestationId, reason, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveRevocation{ value: resolverFeesETH }(_msgSender(), schemaId, attestationId, extraData);
        }
    }

    function revokeBatch(
        uint256[] memory attestationIds,
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
            address storageAttester = _getSPStorage()._attestationRegistry[attestationIds[0]].attester;
            __checkDelegationSignature(storageAttester, getDelegatedRevokeBatchHash(attestationIds), delegateSignature);
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            address storageAttester = _getSPStorage()._attestationRegistry[attestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester(storageAttester, currentAttester);
            }
            uint256 schemaId = _revoke(attestationIds[i], reasons[i], delegateMode);
            ISPHook hook = __getResolverFromAttestationId(attestationIds[i]);
            if (address(hook) != address(0)) {
                hook.didReceiveRevocation{ value: resolverFeesETH[i] }(
                    _msgSender(), schemaId, attestationIds[i], extraData
                );
            }
        }
    }

    function revoke(
        uint256 attestationId,
        string calldata reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        override
    {
        bool delegateMode = delegateSignature.length != 0;
        if (delegateMode) {
            address storageAttester = _getSPStorage()._attestationRegistry[attestationId].attester;
            __checkDelegationSignature(storageAttester, getDelegatedRevokeHash(attestationId), delegateSignature);
        }
        uint256 schemaId = _revoke(attestationId, reason, delegateMode);
        ISPHook hook = __getResolverFromAttestationId(attestationId);
        if (address(hook) != address(0)) {
            hook.didReceiveRevocation(
                _msgSender(), schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount, extraData
            );
        }
    }

    function revokeBatch(
        uint256[] memory attestationIds,
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
            address storageAttester = _getSPStorage()._attestationRegistry[attestationIds[0]].attester;
            __checkDelegationSignature(storageAttester, getDelegatedRevokeBatchHash(attestationIds), delegateSignature);
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < attestationIds.length; i++) {
            address storageAttester = _getSPStorage()._attestationRegistry[attestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester(storageAttester, currentAttester);
            }
            uint256 schemaId = _revoke(attestationIds[i], reasons[i], delegateMode);
            ISPHook hook = __getResolverFromAttestationId(attestationIds[i]);
            if (address(hook) != address(0)) {
                hook.didReceiveRevocation(
                    _msgSender(),
                    schemaId,
                    attestationIds[i],
                    resolverFeesERC20Tokens[i],
                    resolverFeesERC20Amount[i],
                    extraData
                );
            }
        }
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
            address storageAttester = _getSPStorage()._offchainAttestationRegistry[offchainAttestationId].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedOffchainRevokeHash(offchainAttestationId), delegateSignature
            );
        }
        _revokeOffchain(offchainAttestationId, reason, delegateMode);
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
            address storageAttester = _getSPStorage()._offchainAttestationRegistry[offchainAttestationIds[0]].attester;
            __checkDelegationSignature(
                storageAttester, getDelegatedOffchainRevokeBatchHash(offchainAttestationIds), delegateSignature
            );
            currentAttester = storageAttester;
        }
        for (uint256 i = 0; i < offchainAttestationIds.length; i++) {
            address storageAttester = _getSPStorage()._offchainAttestationRegistry[offchainAttestationIds[i]].attester;
            if (delegateMode && storageAttester != currentAttester) {
                revert AttestationWrongAttester(storageAttester, currentAttester);
            }
            _revokeOffchain(offchainAttestationIds[i], reasons[i], delegateMode);
        }
    }

    function getSchema(uint256 schemaId) external view override returns (Schema memory) {
        return _getSPStorage()._schemaRegistry[schemaId];
    }

    function getAttestation(uint256 attestationId) external view override returns (Attestation memory) {
        return _getSPStorage()._attestationRegistry[attestationId];
    }

    function getOffchainAttestation(string calldata offchainAttestationId)
        external
        view
        returns (OffchainAttestation memory)
    {
        return _getSPStorage()._offchainAttestationRegistry[offchainAttestationId];
    }

    function schemaCounter() external view override returns (uint256) {
        return _getSPStorage().schemaCounter;
    }

    function attestationCounter() external view override returns (uint256) {
        return _getSPStorage().attestationCounter;
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
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

    function getDelegatedRevokeHash(uint256 attestationId) public pure override returns (bytes32) {
        return keccak256(abi.encode(REVOKE_ACTION_NAME, attestationId));
    }

    function getDelegatedRevokeBatchHash(uint256[] memory attestationIds) public pure returns (bytes32) {
        return keccak256(abi.encode(REVOKE_BATCH_ACTION_NAME, attestationIds));
    }

    function getDelegatedOffchainRevokeHash(string memory offchainAttestationId)
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOKE_OFFCHAIN_ACTION_NAME, offchainAttestationId));
    }

    function getDelegatedOffchainRevokeBatchHash(string[] memory offchainAttestationIds)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOKE_OFFCHAIN_BATCH_ACTION_NAME, offchainAttestationIds));
    }

    function _register(Schema calldata schema) internal returns (uint256 schemaId) {
        SPStorage storage $ = _getSPStorage();
        schemaId = $.schemaCounter++;
        $._schemaRegistry[schemaId] = schema;
        emit SchemaRegistered(schemaId);
    }

    function _attest(
        Attestation memory attestation,
        string memory indexingKey,
        bool delegateMode
    )
        internal
        returns (uint256 schemaId, uint256 attestationId)
    {
        SPStorage storage $ = _getSPStorage();
        attestationId = $.attestationCounter++;
        // In delegation mode, the attester is already checked ahead of time.
        if (!delegateMode && attestation.attester != _msgSender()) {
            revert AttestationWrongAttester(attestation.attester, _msgSender());
        }
        if (attestation.linkedAttestationId > 0 && !__attestationExists(attestation.linkedAttestationId)) {
            revert AttestationNonexistent(attestation.linkedAttestationId);
        }
        if (
            attestation.linkedAttestationId != 0
                && $._attestationRegistry[attestation.linkedAttestationId].attester != _msgSender()
        ) {
            revert AttestationWrongAttester(
                $._attestationRegistry[attestation.linkedAttestationId].attester, _msgSender()
            );
        }
        Schema memory s = $._schemaRegistry[attestation.schemaId];
        if (!__schemaExists(attestation.schemaId)) revert SchemaNonexistent(attestation.schemaId);
        if (s.maxValidFor > 0) {
            uint256 attestationValidFor = attestation.validUntil - block.timestamp;
            if (s.maxValidFor < attestationValidFor) {
                revert AttestationInvalidDuration(attestationId, s.maxValidFor, uint64(attestationValidFor));
            }
        }
        $._attestationRegistry[attestationId] = attestation;
        emit AttestationMade(attestationId, indexingKey);
        return (attestation.schemaId, attestationId);
    }

    function _attestOffchain(string calldata offchainAttestationId, address attester) internal {
        SPStorage storage $ = _getSPStorage();
        OffchainAttestation storage attestation = $._offchainAttestationRegistry[offchainAttestationId];
        if (__offchainAttestationExists(offchainAttestationId)) {
            revert OffchainAttestationExists(offchainAttestationId);
        }
        attestation.timestamp = uint64(block.timestamp);
        attestation.attester = attester;
        emit OffchainAttestationMade(offchainAttestationId);
    }

    function _revoke(
        uint256 attestationId,
        string memory reason,
        bool delegateMode
    )
        internal
        returns (uint256 schemaId)
    {
        SPStorage storage $ = _getSPStorage();
        Attestation storage a = $._attestationRegistry[attestationId];
        if (a.attester == address(0)) revert AttestationNonexistent(attestationId);
        // In delegation mode, the attester is already checked ahead of time.
        if (!delegateMode && a.attester != _msgSender()) revert AttestationWrongAttester(a.attester, _msgSender());
        Schema memory s = $._schemaRegistry[a.schemaId];
        if (!s.revocable) revert AttestationIrrevocable(a.schemaId, attestationId);
        if (a.revoked) revert AttestationAlreadyRevoked(attestationId);
        a.revoked = true;
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
        OffchainAttestation storage attestation = $._offchainAttestationRegistry[offchainAttestationId];
        if (!__offchainAttestationExists(offchainAttestationId)) {
            revert OffchainAttestationNonexistent(offchainAttestationId);
        }
        if (!delegateMode && attestation.attester != _msgSender()) {
            revert AttestationWrongAttester(attestation.attester, _msgSender());
        }
        if (attestation.timestamp == 1) {
            revert OffchainAttestationAlreadyRevoked(offchainAttestationId);
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

    function __getResolverFromAttestationId(uint256 attestationId) internal view returns (ISPHook) {
        SPStorage storage $ = _getSPStorage();
        Attestation memory a = $._attestationRegistry[attestationId];
        Schema memory s = $._schemaRegistry[a.schemaId];
        return s.hook;
    }

    function __schemaExists(uint256 schemaId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return schemaId < $.schemaCounter;
    }

    function __attestationExists(uint256 attestationId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return attestationId < $.attestationCounter;
    }

    function __offchainAttestationExists(string memory attestationId) internal view returns (bool) {
        SPStorage storage $ = _getSPStorage();
        return $._offchainAttestationRegistry[attestationId].timestamp != 0;
    }
}
