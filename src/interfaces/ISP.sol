// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISPResolver} from "../interfaces/ISPResolver.sol";
import {IVersionable} from "./IVersionable.sol";
import {Schema} from "../models/Schema.sol";
import {Attestation} from "../models/Attestation.sol";
import {DataLocation, SchemaMetadata} from "../models/OffchainResource.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SIGN Attestation Protocol Interface
 * @author Jack Xu @ EthSign
 */
interface ISP is IVersionable {
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

    function register(SchemaMetadata calldata uri, Schema calldata schema) external returns (uint256 schemaId);

    function attest(Attestation calldata attestation) external returns (uint256 attestationId);

    function attest(Attestation calldata attestation, uint256 resolverFeesETH)
        external
        payable
        returns (uint256 attestationId);

    function attest(Attestation calldata attestation, IERC20 resolverFeesERC20Token, uint256 resolverFeesERC20Amount)
        external
        returns (uint256 attestationId);

    function attestOffchain(string calldata attestationId) external;

    function revoke(uint256 attestationId, string calldata reason) external;

    function revoke(uint256 attestationId, string calldata reason, uint256 resolverFeesETH) external payable;

    function revoke(
        uint256 attestationId,
        string calldata reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external;

    function revokeOffchain(string calldata attestationId, string calldata reason) external;

    function registerBatch(SchemaMetadata[] calldata uris, Schema[] calldata schemas)
        external
        returns (uint256[] memory schemaIds);

    function attestBatch(Attestation[] calldata attestations) external returns (uint256[] memory attestationIds);

    function attestBatch(Attestation[] calldata attestations, uint256[] calldata resolverFeesETH)
        external
        payable
        returns (uint256[] memory attestationIds);

    function attestBatch(
        Attestation[] calldata attestations,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external returns (uint256[] memory attestationIds);

    function attestOffchainBatch(string[] calldata attestationIds) external;

    function revokeBatch(uint256[] calldata attestationIds, string[] calldata reasons) external;

    function revokeBatch(
        uint256[] calldata attestationIds,
        string[] calldata reasons,
        uint256[] calldata resolverFeesETH
    ) external payable;

    function revokeBatch(
        uint256[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;

    function revokeOffchainBatch(string[] calldata attestationIds, string[] calldata reasons) external;

    function getSchema(uint256 schemaId) external view returns (Schema memory);

    function getAttestation(uint256 attestationId) external view returns (Attestation memory);

    function getOffchainAttestation(string calldata attestationId) external view returns (uint256 timestamp);

    function schemaCounter() external view returns (uint256);

    function attestationCounter() external view returns (uint256);
}
