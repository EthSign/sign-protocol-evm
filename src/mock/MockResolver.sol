// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISAP} from "../interfaces/ISAP.sol";
import {ISAPResolver, IERC20} from "../interfaces/ISAPResolver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockResolverAdmin is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    mapping(string => uint256) internal _schemaAttestETHFees;
    mapping(string => mapping(IERC20 => uint256)) internal _schemaAttestTokenFees;

    error MismatchETHFee();
    error InsufficientETHFee();
    error InsufficientTokenFee();

    function initialize() external initializer {
        __Ownable_init(_msgSender());
    }

    function setSchemaAttestETHFees(string calldata schemaId, uint256 fees) external onlyOwner {
        _schemaAttestETHFees[schemaId] = fees;
    }

    function setSchemaAttestTokenFees(string calldata schemaId, IERC20 token, uint256 fees) external onlyOwner {
        _schemaAttestTokenFees[schemaId][token] = fees;
    }

    function _receiveEther(address attester, string calldata attestationId, uint256 resolverFeesETH) internal {
        if (resolverFeesETH != msg.value) revert MismatchETHFee();
        string memory schemaId = ISAP(_msgSender()).getSchemaIdFromAttestationId(attestationId);
        if (resolverFeesETH != _schemaAttestETHFees[schemaId]) revert InsufficientETHFee();
        attester;
    }

    function _receiveTokens(
        address attester,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) internal {
        string memory schemaId = ISAP(_msgSender()).getSchemaIdFromAttestationId(attestationId);
        if (resolverFeeERC20Amount != _schemaAttestTokenFees[schemaId][resolverFeeERC20Token]) {
            revert InsufficientTokenFee();
        }
        resolverFeeERC20Token.safeTransferFrom(attester, address(this), resolverFeeERC20Amount);
    }
}

contract MockResolver is ISAPResolver, MockResolverAdmin {
    function didReceiveAttestation(address attester, string calldata attestationId) external payable override {}

    function didReceiveAttestation(
        address attester,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }

    function didReceiveOffchainAttestation(address attester, string calldata attestationId) external payable override {}

    function didReceiveOffchainAttestation(
        address attester,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }

    function didReceiveRevocation(address attester, string calldata attestationId) external payable override {}

    function didReceiveRevocation(
        address attester,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }

    function didReceiveOffchainRevocation(address attester, string calldata attestationId) external payable override {}

    function didReceiveOffchainRevocation(
        address attester,
        string calldata attestationId,
        IERC20 resolverFeeERC20Token,
        uint256 resolverFeeERC20Amount
    ) external override {
        _receiveTokens(attester, attestationId, resolverFeeERC20Token, resolverFeeERC20Amount);
    }
}
