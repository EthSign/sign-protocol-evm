// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAP} from "../interfaces/ISAP.sol";
import {ISAPResolver} from "../interfaces/ISAPResolver.sol";
import {Schema} from "../models/Schema.sol";
import {Attestation} from "../models/Attestation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SAP is ISAP {
    mapping(string => Schema) public schemaRegistry;
    mapping(string => Attestation) public attestationRegistry;
    mapping(string => uint256) public offchainAttestationRegistry;

    function register(string[] calldata schemaIds, Schema[] calldata schemas) external override {
        for (uint256 i = 0; i < schemaIds.length; i++) {
            _register(schemaIds[i], schemas[i]);
        }
    }

    function attest(string[] calldata attestationIds, Attestation[] calldata attestations) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attest(attestationIds[i], attestations[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveAttestation(attestationIds[i]);
        }
    }

    function attest(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        uint256[] calldata resolverFeesETH
    ) external payable override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attest(attestationIds[i], attestations[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveAttestation{value: resolverFeesETH[i]}(
                attestationIds[i]
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
            _attest(attestationIds[i], attestations[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveAttestation(
                attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
            );
        }
    }

    function attestOffchain(string[] calldata attestationIds) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveOffchainAttestation(attestationIds[i]);
        }
    }

    function attestOffchain(string[] calldata attestationIds, uint256[] calldata resolverFeesETH)
        external
        payable
        override
    {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveOffchainAttestation{value: resolverFeesETH[i]}(
                attestationIds[i]
            );
        }
    }

    function attestOffchain(
        string[] calldata attestationIds,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _attestOffchain(attestationIds[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveOffchainAttestation(
                attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
            );
        }
    }

    function revoke(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revoke(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveRevocation(attestationIds[i]);
        }
    }

    function revoke(string[] calldata attestationIds, string[] calldata reasons, uint256[] calldata resolverFeesETH)
        external
        payable
        override
    {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revoke(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveRevocation{value: resolverFeesETH[i]}(
                attestationIds[i]
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
            _revoke(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveRevocation(
                attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
            );
        }
    }

    function revokeOffchain(string[] calldata attestationIds, string[] calldata reasons) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revokeOffchain(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveOffchainRevocation(attestationIds[i]);
        }
    }

    function revokeOffchain(
        string[] calldata attestationIds,
        string[] calldata reasons,
        uint256[] calldata resolverFeesETH
    ) external payable override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revokeOffchain(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveOffchainRevocation{value: resolverFeesETH[i]}(
                attestationIds[i]
            );
        }
    }

    function revokeOffchain(
        string[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external override {
        for (uint256 i = 0; i < attestationIds.length; i++) {
            _revokeOffchain(attestationIds[i], reasons[i]);
            __getResolverFromAttestationId(attestationIds[i]).didReceiveOffchainRevocation(
                attestationIds[i], resolverFeesERC20Tokens[i], resolverFeesERC20Amount[i]
            );
        }
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function _register(string calldata schemaId, Schema calldata schema) internal {
        Schema memory s = schemaRegistry[schemaId];
        if (bytes(s.schema).length != 0) revert SchemaExists(schemaId);
        schemaRegistry[schemaId] = schema;
        emit SchemaRegistered(schemaId);
    }

    function _attest(string calldata attestationId, Attestation calldata attestation) internal {
        Attestation memory a = attestationRegistry[attestationId];
        if (a.attester != address(0)) revert AttestationExists(attestationId);
        Schema memory s = schemaRegistry[attestation.schemaId];
        if (bytes(s.schema).length == 0) revert SchemaNonexistent(attestation.schemaId);
        uint256 attestationValidFor = attestation.validUntil - block.timestamp;
        if (s.maxValidFor != 0 && s.maxValidFor < attestationValidFor) {
            revert AttestationInvalidDuration(attestationId, s.maxValidFor, attestationValidFor);
        }
        attestationRegistry[attestationId] = attestation;
        emit AttestationMade(attestationId);
    }

    function _attestOffchain(string calldata attestationId) internal {
        if (offchainAttestationRegistry[attestationId] != 0) revert AttestationExists(attestationId);
        offchainAttestationRegistry[attestationId] = block.timestamp;
        emit OffchainAttestationMade(attestationId);
    }

    function _revoke(string calldata attestationId, string calldata reason) internal {
        Attestation memory a = attestationRegistry[attestationId];
        if (a.attester == address(0)) revert AttestationNonexistent(attestationId);
        Schema memory s = schemaRegistry[a.schemaId];
        if (!s.revocable) revert AttestationIrrevocable(a.schemaId, attestationId);
        if (a.revoked) revert AttestationAlreadyRevoked(attestationId);
        a.revoked = true;
        emit AttestationRevoked(attestationId, reason);
    }

    function _revokeOffchain(string calldata attestationId, string calldata reason) internal {
        if (offchainAttestationRegistry[attestationId] == 0) revert AttestationNonexistent(attestationId);
        offchainAttestationRegistry[attestationId] = 0;
        emit AttestationRevoked(attestationId, reason);
    }

    function __getResolverFromAttestationId(string calldata attestationId) internal view returns (ISAPResolver) {
        Attestation memory a = attestationRegistry[attestationId];
        Schema memory s = schemaRegistry[a.schemaId];
        return s.resolver;
    }
}
