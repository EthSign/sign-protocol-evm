// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAPResolver} from "../interfaces/ISAPResolver.sol";
import {IVersionable} from "./IVersionable.sol";
import {Schema} from "../models/Schema.sol";
import {Attestation} from "../models/Attestation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SIGN Attestation Protocol Interface
 * @author Jack Xu @ EthSign
 */
interface ISAP is IVersionable {
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

    function register(string calldata schemaId, Schema calldata schema) external;

    function attest(string calldata attestationId, Attestation calldata attestation) external;

    function attest(string calldata attestationId, Attestation calldata attestation, uint256 resolverFeesETH)
        external
        payable;

    function attest(
        string calldata attestationId,
        Attestation calldata attestation,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external;

    function attestOffchain(string calldata attestationId) external;

    function revoke(string calldata attestationId, string calldata reason) external;

    function revoke(string calldata attestationId, string calldata reason, uint256 resolverFeesETH) external payable;

    function revoke(
        string calldata attestationId,
        string calldata reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external;

    function revokeOffchain(string calldata attestationId, string calldata reason) external;

    function registerBatch(string[] calldata schemaIds, Schema[] calldata schemas) external;

    function attestBatch(string[] calldata attestationIds, Attestation[] calldata attestations) external;

    function attestBatch(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        uint256[] calldata resolverFeesETH
    ) external payable;

    function attestBatch(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;

    function attestOffchainBatch(string[] calldata attestationIds) external;

    function revokeBatch(string[] calldata attestationIds, string[] calldata reasons) external;

    function revokeBatch(
        string[] calldata attestationIds,
        string[] calldata reasons,
        uint256[] calldata resolverFeesETH
    ) external payable;

    function revokeBatch(
        string[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;

    function revokeOffchainBatch(string[] calldata attestationIds, string[] calldata reasons) external;

    function getSchema(string calldata schemaId) external view returns (Schema memory);

    function getAttestation(string calldata attestationId) external view returns (Attestation memory);

    function getOffchainAttestation(string calldata attestationId) external view returns (uint256 timestamp);
}
