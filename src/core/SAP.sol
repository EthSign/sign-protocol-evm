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
    mapping(string => uint256) public override offchainAttestationRegistry;

    function initialize() external initializer {
        __Ownable_init(_msgSender());
    }

    function register(string[] calldata schemaIds, Schema[] calldata schemas) external override {
        for (uint256 i = 0; i < schemaIds.length; i++) {
            _register(schemaIds[i], schemas[i]);
        }
    }

    function attest(string[] calldata attestationIds, Attestation[] calldata attestations) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _attest(attestationIds[i], attestations[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveAttestation(
                _msgSender(), schemaId, attestationIds[i]
            );
        }
    }

    function attest(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        uint256[] calldata resolverFeesETH
    ) external payable override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _attest(attestationIds[i], attestations[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveAttestation{value: resolverFeesETH[i]}(
                _msgSender(), schemaId, attestationIds[i]
            );
        }
    }

    function attest(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _attest(attestationIds[i], attestations[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveAttestation(
                _msgSender(), schemaId, attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
            );
        }
    }

    function attestOffchain(string[] calldata attestationIds) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i]);
        }
    }

    function revoke(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _revoke(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveRevocation(
                _msgSender(), schemaId, attestationIds[i]
            );
        }
    }

    function revoke(string[] calldata attestationIds, string[] calldata reasons, uint256[] calldata resolverFeesETH)
        external
        payable
        override
    {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _revoke(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveRevocation{value: resolverFeesETH[i]}(
                _msgSender(), schemaId, attestationIds[i]
            );
        }
    }

    function revoke(
        string[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            string memory schemaId = _revoke(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveRevocation(
                _msgSender(), schemaId, attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
            );
        }
    }

    function revokeOffchain(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revokeOffchain(attestationIds[i], reasons[i]);
        }
    }

    function schemaRegistry(string calldata schemaId) external view override returns (Schema memory) {
        return _schemaRegistry[schemaId];
    }

    function attestationRegistry(string calldata attestationId) external view override returns (Attestation memory) {
        return _attestationRegistry[attestationId];
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function _register(string calldata schemaId, Schema calldata schema) internal {
        Schema memory s = _schemaRegistry[schemaId];
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
        if (attestation.revoked) revert AttestationAlreadyRevoked(attestationId);
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
        if (offchainAttestationRegistry[attestationId] != 0) revert AttestationExists(attestationId);
        offchainAttestationRegistry[attestationId] = block.timestamp;
        emit OffchainAttestationMade(attestationId);
    }

    function _revoke(string calldata attestationId, string calldata reason) internal returns (string memory schemaId) {
        Attestation memory a = _attestationRegistry[attestationId];
        if (a.attester == address(0)) revert AttestationNonexistent(attestationId);
        Schema memory s = _schemaRegistry[a.schemaId];
        if (!s.revocable) revert AttestationIrrevocable(a.schemaId, attestationId);
        if (a.revoked) revert AttestationAlreadyRevoked(attestationId);
        a.revoked = true;
        emit AttestationRevoked(attestationId, reason);
        return a.schemaId;
    }

    function _revokeOffchain(string calldata attestationId, string calldata reason) internal {
        if (offchainAttestationRegistry[attestationId] == 0) revert AttestationNonexistent(attestationId);
        offchainAttestationRegistry[attestationId] = 0;
        emit AttestationRevoked(attestationId, reason);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    function __getResolverFromAttestationId(string calldata attestationId) internal view returns (ISAPResolver) {
        Attestation memory a = _attestationRegistry[attestationId];
        Schema memory s = _schemaRegistry[a.schemaId];
        return s.resolver;
    }
}
