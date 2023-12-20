// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAP} from "../interfaces/ISAP.sol";
import {ISAPResolver, IERC20} from "../interfaces/ISAPResolver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockResolverAdmin is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    mapping(string => uint256) public schemaAttestETHFees;
    mapping(string => mapping(IERC20 => uint256)) public schemaAttestTokenFees;
    mapping(string => uint256) public attestationETHFees;
    mapping(string => mapping(IERC20 => uint256)) public attestationTokenFees;
    mapping(IERC20 => bool) public approvedTokens;

    event ETHFeesReceived(string attestationId, uint256 amount);
    event TokenFeesReceived(string attestationId, IERC20 token, uint256 amount);

    error MismatchETHFee();
    error InsufficientETHFee();
    error UnapprovedToken();
    error InsufficientTokenFee();

    function initialize() external initializer {
        __Ownable_init(_msgSender());
    }

    function setSchemaAttestETHFees(string calldata schemaId, uint256 fees) external onlyOwner {
        schemaAttestETHFees[schemaId] = fees;
    }

    function setSchemaAttestTokenFees(string calldata schemaId, IERC20 token, uint256 fees) external onlyOwner {
        schemaAttestTokenFees[schemaId][token] = fees;
    }

    function setFeeTokenApprovalStatus(IERC20 token, bool approved) external onlyOwner {
        approvedTokens[token] = approved;
    }

    function _receiveEther(address attester, string memory schemaId, string calldata attestationId) internal {
        uint256 fees = bytes(schemaId).length == 0 ? attestationETHFees[attestationId] : schemaAttestETHFees[schemaId];
        if (msg.value != fees) revert InsufficientETHFee();
        emit ETHFeesReceived(attestationId, msg.value);
        attester;
    }

    function _receiveTokens(
        address attester,
        string memory schemaId,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) internal {
        if (!approvedTokens[resolverFeeERC20Token]) revert UnapprovedToken();
        uint256 fees = bytes(schemaId).length == 0
            ? attestationTokenFees[attestationId][resolverFeeERC20Token]
            : schemaAttestTokenFees[schemaId][resolverFeeERC20Token];
        if (resolverFeeERC20Amount != fees) revert InsufficientTokenFee();
        resolverFeeERC20Token.safeTransferFrom(attester, address(this), resolverFeeERC20Amount);
        emit TokenFeesReceived(attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }
}

contract MockResolver is ISAPResolver, MockResolverAdmin {
    function didReceiveAttestation(address attester, string calldata schemaId, string calldata attestationId)
        external
        payable
        override
    {}

    function didReceiveAttestation(
        address attester,
        string calldata schemaId,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, schemaId, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }

    function didReceiveRevocation(address attester, string calldata schemaId, string calldata attestationId)
        external
        payable
        override
    {
        _receiveEther(attester, schemaId, attestationId);
    }

    function didReceiveRevocation(
        address attester,
        string calldata schemaId,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, schemaId, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }
}
