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
    error SchemaIdsExist(string[] existingSchemaIds);
    error SchemaIdsNonexistent(string[] nonexistentSchemaIds);
    error SchemaIrrevocable(string[] schemaIds, string[] offendingAttestationIds);
    error AttestationIdsExist(string[] existingAttestationIds);
    error AttestationIdsNonexistent(string[] nonexistentAttestationIds);
    error AttestationsInvalidDuration(
        string[] offendingAttestationIds, uint256[] maxDurations, uint256[] inputDurations
    );
    error AttestationsAlreadyRevoked(string[] offendingAttestationIds);
    error ResolverReverted(string reason);

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
        address[] calldata resolverFeesERC20Tokens,
        uint256[] calldata resolverFeesERC20Amount
    ) external;
}
