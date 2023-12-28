// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISP} from "../interfaces/ISP.sol";
import {ISPResolver, IERC20} from "../interfaces/ISPResolver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockResolverAdmin is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    mapping(uint256 => uint256) public schemaAttestETHFees;
    mapping(uint256 => mapping(IERC20 => uint256)) public schemaAttestTokenFees;
    mapping(uint256 => uint256) public attestationETHFees;
    mapping(uint256 => mapping(IERC20 => uint256)) public attestationTokenFees;
    mapping(IERC20 => bool) public approvedTokens;

    event ETHFeesReceived(uint256 attestationId, uint256 amount);
    event TokenFeesReceived(uint256 attestationId, IERC20 token, uint256 amount);

    error MismatchETHFee();
    error InsufficientETHFee();
    error UnapprovedToken();
    error InsufficientTokenFee();

    function initialize() external initializer {
        __Ownable_init(_msgSender());
    }

    function setSchemaAttestETHFees(uint256 schemaId, uint256 fees) external onlyOwner {
        schemaAttestETHFees[schemaId] = fees;
    }

    function setSchemaAttestTokenFees(uint256 schemaId, IERC20 token, uint256 fees) external onlyOwner {
        schemaAttestTokenFees[schemaId][token] = fees;
    }

    function setFeeTokenApprovalStatus(IERC20 token, bool approved) external onlyOwner {
        approvedTokens[token] = approved;
    }

    function _receiveEther(address attester, uint256 schemaId, uint256 attestationId) internal {
        uint256 fees =
            schemaAttestETHFees[schemaId] == 0 ? attestationETHFees[attestationId] : schemaAttestETHFees[schemaId];
        if (msg.value != fees) revert InsufficientETHFee();
        emit ETHFeesReceived(attestationId, msg.value);
        attester;
    }

    function _receiveTokens(
        address attester,
        uint256 schemaId,
        uint256 attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) internal {
        if (!approvedTokens[resolverFeeERC20Token]) revert UnapprovedToken();
        uint256 fees = schemaAttestTokenFees[schemaId][resolverFeeERC20Token] == 0
            ? attestationTokenFees[attestationId][resolverFeeERC20Token]
            : schemaAttestTokenFees[schemaId][resolverFeeERC20Token];
        if (resolverFeeERC20Amount != fees) revert InsufficientTokenFee();
        resolverFeeERC20Token.safeTransferFrom(attester, address(this), resolverFeeERC20Amount);
        emit TokenFeesReceived(attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }
}

contract MockResolver is ISPResolver, MockResolverAdmin {
    function didReceiveAttestation(address attester, uint256 schemaId, uint256 attestationId)
        external
        payable
        override
    {}

    function didReceiveAttestation(
        address attester,
        uint256 schemaId,
        uint256 attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, schemaId, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }

    function didReceiveRevocation(address attester, uint256 schemaId, uint256 attestationId)
        external
        payable
        override
    {
        _receiveEther(attester, schemaId, attestationId);
    }

    function didReceiveRevocation(
        address attester,
        uint256 schemaId,
        uint256 attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, schemaId, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }
}
