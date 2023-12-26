// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAP} from "../interfaces/ISAP.sol";
import {ISAPResolver} from "../interfaces/ISAPResolver.sol";
import {Schema} from "../models/Schema.sol";
import {Attestation} from "../models/Attestation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SAP is ISAP, UUPSUpgradeable, OwnableUpgradeable {
    mapping(string => Schema) internal _schemaRegistry;
    mapping(string => Attestation) internal _attestationRegistry;
    mapping(string => uint256) internal _offchainAttestationRegistry;

    function initialize() external initializer {
        __Ownable_init(_msgSender());
    }

    function register(string calldata schemaId, Schema calldata schema) external override {
        _register(schemaId, schema);
    }

    function registerBatch(string[] calldata schemaIds, Schema[] calldata schemas) external override {
        for (uint256 i = 0; i < schemaIds.length; i++) {
            _register(schemaIds[i], schemas[i]);
        }
    }

    function attest(string calldata attestationId, Attestation calldata attestation) external override {
        string memory schemaId = _attest(attestationId, attestation);
        ISAPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) resolver.didReceiveAttestation(_msgSender(), schemaId, attestationId);
    }

    function attestBatch(string[] calldata attestationIds, Attestation[] calldata attestations) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _attest(attestationIds[i], attestations[i]);
            ISAPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveAttestation(_msgSender(), schemaId, attestationIds[i]);
            }
        }
    }

    function attest(string calldata attestationId, Attestation calldata attestation, uint256 resolverFeesETH)
        external
        payable
    {
        string memory schemaId = _attest(attestationId, attestation);
        ISAPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveAttestation{value: resolverFeesETH}(_msgSender(), schemaId, attestationId);
        }
    }

    function attestBatch(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        uint256[] calldata resolverFeesETH
    ) external payable override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _attest(attestationIds[i], attestations[i]);
            ISAPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveAttestation{value: resolverFeesETH[i]}(_msgSender(), schemaId, attestationIds[i]);
            }
        }
    }

    function attest(
        string calldata attestationId,
        Attestation calldata attestation,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external override {
        string memory schemaId = _attest(attestationId, attestation);
        ISAPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveAttestation(
                _msgSender(), schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount
            );
        }
    }

    function attestBatch(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _attest(attestationIds[i], attestations[i]);
            ISAPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveAttestation(
                    _msgSender(), schemaId, attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
                );
            }
        }
    }

    function attestOffchain(string calldata attestationId) external override {
        _attestOffchain(attestationId);
    }

    function attestOffchainBatch(string[] calldata attestationIds) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i]);
        }
    }

    function revoke(string calldata attestationId, string calldata reason) external override {
        string memory schemaId = _revoke(attestationId, reason);
        ISAPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveRevocation(_msgSender(), schemaId, attestationId);
        }
    }

    function revokeBatch(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _revoke(attestationIds[i], reasons[i]);
            ISAPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveRevocation(_msgSender(), schemaId, attestationIds[i]);
            }
        }
    }

    function revoke(string calldata attestationId, string calldata reason, uint256 resolverFeesETH)
        external
        payable
        override
    {
        string memory schemaId = _revoke(attestationId, reason);
        ISAPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveRevocation{value: resolverFeesETH}(_msgSender(), schemaId, attestationId);
        }
    }

    function revokeBatch(
        string[] calldata attestationIds,
        string[] calldata reasons,
        uint256[] calldata resolverFeesETH
    ) external payable override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _revoke(attestationIds[i], reasons[i]);
            ISAPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveRevocation{value: resolverFeesETH[i]}(_msgSender(), schemaId, attestationIds[i]);
            }
        }
    }

    function revoke(
        string calldata attestationId,
        string calldata reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external override {
        string memory schemaId = _revoke(attestationId, reason);
        ISAPResolver resolver = __getResolverFromAttestationId(attestationId);
        if (address(resolver) != address(0)) {
            resolver.didReceiveRevocation(
                _msgSender(), schemaId, attestationId, resolverFeesERC20Token, resolverFeesERC20Amount
            );
        }
    }

    function revokeBatch(
        string[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _revoke(attestationIds[i], reasons[i]);
            ISAPResolver resolver = __getResolverFromAttestationId(attestationIds[i]);
            if (address(resolver) != address(0)) {
                resolver.didReceiveRevocation(
                    _msgSender(), schemaId, attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
                );
            }
        }
    }

    function revokeOffchain(string calldata attestationId, string calldata reason) external override {
        _revokeOffchain(attestationId, reason);
    }

    function revokeOffchainBatch(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revokeOffchain(attestationIds[i], reasons[i]);
        }
    }

    function getSchema(string calldata schemaId) external view override returns (Schema memory) {
        return _schemaRegistry[schemaId];
    }

    function getAttestation(string calldata attestationId) external view override returns (Attestation memory) {
        return _attestationRegistry[attestationId];
    }

    function getOffchainAttestation(string calldata attestationId) external view returns (uint256 timestamp) {
        return _offchainAttestationRegistry[attestationId];
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function _register(string calldata schemaId, Schema calldata schema) internal {
        Schema memory s = _schemaRegistry[schemaId];
        if (bytes(schemaId).length == 0) revert SchemaIdInvalid();
        if (bytes(s.schema).length != 0) revert SchemaExists(schemaId);
        _schemaRegistry[schemaId] = schema;
        emit SchemaRegistered(schemaId);
    }

    function _attest(string calldata attestationId, Attestation calldata attestation)
        internal
        returns (string memory schemaId)
    {
        Attestation memory a = _attestationRegistry[attestationId];
        if (a.attester != address(0)) revert AttestationExists(attestationId);
        if (attestation.attester != _msgSender()) revert AttestationWrongAttester(attestation.attester, _msgSender());
        if (
            bytes(attestation.linkedAttestationId).length > 0
                && bytes(_attestationRegistry[attestation.linkedAttestationId].schemaId).length == 0
        ) {
            revert AttestationNonexistent(attestation.linkedAttestationId);
        }
        if (
            bytes(attestation.linkedAttestationId).length > 0
                && _attestationRegistry[attestation.linkedAttestationId].attester != _msgSender()
        ) revert AttestationWrongAttester(_attestationRegistry[attestation.linkedAttestationId].attester, _msgSender());
        Schema memory s = _schemaRegistry[attestation.schemaId];
        if (bytes(s.schema).length == 0) revert SchemaNonexistent(attestation.schemaId);
        uint256 attestationValidFor = attestation.validUntil - block.timestamp;
        if (s.maxValidFor != 0 && s.maxValidFor < attestationValidFor) {
            revert AttestationInvalidDuration(attestationId, s.maxValidFor, uint64(attestationValidFor));
        }
        _attestationRegistry[attestationId] = attestation;
        emit AttestationMade(attestationId);
        return attestation.schemaId;
    }

    function _attestOffchain(string calldata attestationId) internal {
        if (_offchainAttestationRegistry[attestationId] != 0) revert AttestationExists(attestationId);
        _offchainAttestationRegistry[attestationId] = block.timestamp;
        emit OffchainAttestationMade(attestationId);
    }

    function _revoke(string calldata attestationId, string calldata reason) internal returns (string memory schemaId) {
        Attestation storage a = _attestationRegistry[attestationId];
        if (a.attester == address(0)) revert AttestationNonexistent(attestationId);
        if (a.attester != _msgSender()) revert AttestationWrongAttester(a.attester, _msgSender());
        Schema memory s = _schemaRegistry[a.schemaId];
        if (!s.revocable) revert AttestationIrrevocable(a.schemaId, attestationId);
        if (a.revoked) revert AttestationAlreadyRevoked(attestationId);
        a.revoked = true;
        emit AttestationRevoked(attestationId, reason);
        return a.schemaId;
    }

    function _revokeOffchain(string calldata attestationId, string calldata reason) internal {
        if (_offchainAttestationRegistry[attestationId] == 0) revert AttestationNonexistent(attestationId);
        if (_offchainAttestationRegistry[attestationId] == 1) revert AttestationAlreadyRevoked(attestationId);
        _offchainAttestationRegistry[attestationId] = 1;
        emit OffchainAttestationRevoked(attestationId, reason);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    function __getResolverFromAttestationId(string calldata attestationId) internal view returns (ISAPResolver) {
        Attestation memory a = _attestationRegistry[attestationId];
        Schema memory s = _schemaRegistry[a.schemaId];
        return s.resolver;
    }
}
