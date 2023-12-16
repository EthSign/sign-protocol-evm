// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SIGN Attestation Protocol Resolver Interface
 * @author Jack Xu @ EthSign
 */
interface ISAPResolver {
    function didReceiveAttestation(string calldata attestationId) external payable;

    function didReceiveAttestation(
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external;

    function didReceiveOffchainAttestation(string calldata attestationId) external payable;

    function didReceiveOffchainAttestation(
        string calldata attestationIds,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeesERC20Amount
    ) external;

    function didReceiveRevocation(string calldata attestationId) external payable;

    function didReceiveRevocation(
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external;

    function didReceiveOffchainRevocation(string calldata attestationId) external payable;

    function didReceiveOffchainRevocation(
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external;
}
