// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SIGN Attestation Protocol Resolver Interface
 * @author Jack Xu @ EthSign
 */
interface ISAPResolver {
    function didReceiveAttestation(address attester, string calldata schemaId, string calldata attestationId)
        external
        payable;

    function didReceiveAttestation(
        address attester,
        string calldata schemaId,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external;

    function didReceiveRevocation(address attester, string calldata schemaId, string calldata attestationId)
        external
        payable;

    function didReceiveRevocation(
        address attester,
        string calldata schemaId,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external;
}
