// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISPResolver} from "../interfaces/ISPResolver.sol";
import {IVersionable} from "./IVersionable.sol";
import {Schema} from "../models/Schema.sol";
import {Attestation, OffchainAttestation} from "../models/Attestation.sol";
import {DataLocation, SchemaMetadata} from "../models/OffchainResource.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Sign Protocol Interface
 * @author Jack Xu @ EthSign
 */
interface ISP is IVersionable {
    event SchemaRegistered(uint256 schemaId, DataLocation metadataDataLocation, string metadataUri);
    event AttestationMade(uint256 attestationId);
    event AttestationRevoked(uint256 attestationId, string reason);
    event OffchainAttestationMade(string attestationId);
    event OffchainAttestationRevoked(string attestationId, string reason);

    /**
     * @dev 0x38f8c6c4
     */
    error SchemaNonexistent(uint256 nonexistentSchemaId);
    /**
     * @dev 0x8ac42f49
     */
    error AttestationIrrevocable(uint256 schemaId, uint256 offendingAttestationId);
    /**
     * @dev 0x54681a13
     */
    error AttestationNonexistent(uint256 nonexistentAttestationId);
    /**
     * @dev 0xa65e02ed
     */
    error AttestationInvalidDuration(uint256 offendingAttestationId, uint64 maxDuration, uint64 inputDuration);
    /**
     * @dev 0xd8c3da86
     */
    error AttestationAlreadyRevoked(uint256 offendingAttestationId);
    /**
     * @dev 0xa9ad2007
     */
    error AttestationWrongAttester(address expected, address actual);
    /**
     * @dev 0xc83e3cdf
     */
    error OffchainAttestationExists(string existingOffchainAttestationId);
    /**
     * @dev 0xa006519a
     */
    error OffchainAttestationNonexistent(string nonexistentOffchainAttestationId);
    /**
     * @dev 0xa0671d20
     */
    error OffchainAttestationAlreadyRevoked(string offendingOffchainAttestationId);

    /**
     * @notice Registers a Schema.
     * @dev Emits `SchemaRegistered`.
     * @param uri See `SchemaMetadata`.
     * @param schema See `Schema`.
     * @return schemaId The assigned ID of the registered schema.
     */
    function register(SchemaMetadata calldata uri, Schema calldata schema) external returns (uint256 schemaId);

    /**
     * @notice Makes an attestation.
     * @dev Emits `AttestationMade`.
     * @param attestation See `Attestation`.
     * @return attestationId The assigned ID of the attestation.
     */
    function attest(Attestation calldata attestation) external returns (uint256 attestationId);

    /**
     * @notice Makes an attestation where the schema resolver expects ETH payment.
     * @dev Emits `AttestationMade`.
     * @param attestation See `Attestation`.
     * @param resolverFeesETH Amount of funds to send to the resolver.
     * @return attestationId The assigned ID of the attestation.
     */
    function attest(Attestation calldata attestation, uint256 resolverFeesETH)
        external
        payable
        returns (uint256 attestationId);

    /**
     * @notice Makes an attestation where the schema resolver expects ERC20 payment.
     * @dev Emits `AttestationMade`.
     * @param attestation See `Attestation`.
     * @param resolverFeesERC20Token ERC20 token address used for payment.
     * @param resolverFeesERC20Amount Amount of funds to send to the resolver.
     * @return attestationId The assigned ID of the attestation.
     */
    function attest(Attestation calldata attestation, IERC20 resolverFeesERC20Token, uint256 resolverFeesERC20Amount)
        external
        returns (uint256 attestationId);

    /**
     * @notice Timestamps an off-chain data ID.
     * @dev Emits `OffchainAttestationMade`.
     * @param attestationId The off-chain data ID.
     */
    function attestOffchain(string calldata attestationId) external;

    /**
     * @notice Revokes an existing attestation.
     * @dev Emits `AttestationRevoked`. Must be called by the attester.
     * @param attestationId An existing attestation ID.
     * @param reason The revocation reason. This is only emitted as an event to save gas.
     */
    function revoke(uint256 attestationId, string calldata reason) external;

    /**
     * @notice Revokes an existing attestation where the schema resolver expects ERC20 payment.
     * @dev Emits `AttestationRevoked`. Must be called by the attester.
     * @param attestationId An existing attestation ID.
     * @param reason The revocation reason. This is only emitted as an event to save gas.
     * @param resolverFeesETH Amount of funds to send to the resolver.
     */
    function revoke(uint256 attestationId, string calldata reason, uint256 resolverFeesETH) external payable;

    /**
     * @notice Revokes an existing attestation where the schema resolver expects ERC20 payment.
     * @dev Emits `AttestationRevoked`. Must be called by the attester.
     * @param attestationId An existing attestation ID.
     * @param reason The revocation reason. This is only emitted as an event to save gas.
     * @param resolverFeesERC20Token ERC20 token address used for payment.
     * @param resolverFeesERC20Amount Amount of funds to send to the resolver.
     */
    function revoke(
        uint256 attestationId,
        string calldata reason,
        IERC20 resolverFeesERC20Token,
        uint256 resolverFeesERC20Amount
    ) external;

    /**
     * @notice Revokes an existing offchain attestation.
     * @dev Emits `OffchainAttestationRevoked`. Must be called by the attester.
     * @param attestationId An existing attestation ID.
     * @param reason The revocation reason. This is only emitted as an event to save gas.
     */
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

    function getOffchainAttestation(string calldata attestationId) external view returns (OffchainAttestation memory);

    function schemaCounter() external view returns (uint256);

    function attestationCounter() external view returns (uint256);
}
