// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

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

    error SchemaExists(string existingSchemaId);
    error SchemaNonexistent(string nonexistentSchemaIds);
    error AttestationIrrevocable(string schemaId, string offendingAttestationId);
    error AttestationExists(string existingAttestationId);
    error AttestationNonexistent(string nonexistentAttestationId);
    error AttestationInvalidDuration(string offendingAttestationId, uint256 maxDuration, uint256 inputDuration);
    error AttestationAlreadyRevoked(string offendingAttestationId);

    function register(string[] calldata schemaIds, Schema[] calldata schemas) external;

    function attest(string[] calldata attestationIds, Attestation[] calldata attestations) external;

    function attest(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        uint256[] calldata resolverFeesETH
    ) external payable;

    function attest(
        string[] calldata attestationIds,
        Attestation[] calldata attestations,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;

    function attestOffchain(string[] calldata attestationIds) external;

    function attestOffchain(string[] calldata attestationIds, uint256[] calldata resolverFeesETH) external payable;

    function attestOffchain(
        string[] calldata attestationIds,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;

    function revoke(string[] calldata attestationIds, string[] calldata reasons) external;

    function revoke(string[] calldata attestationIds, string[] calldata reasons, uint256[] calldata resolverFeesETH)
        external
        payable;

    function revoke(
        string[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;

    function revokeOffchain(string[] calldata attestationIds, string[] calldata reasons) external;

    function revokeOffchain(
        string[] calldata attestationIds,
        string[] calldata reasons,
        uint256[] calldata resolverFeesETH
    ) external payable;

    function revokeOffchain(
        string[] calldata attestationIds,
        string[] calldata reasons,
        IERC20[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;
}
