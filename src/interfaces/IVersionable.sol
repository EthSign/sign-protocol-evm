// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVersionable
 * @author Jack Xu @ EthSign
 * @dev This interface helps contracts to keep track of their versioning for upgrade compatibility checks.
 */
interface IVersionable {
    function version() external pure returns (string memory);
}
