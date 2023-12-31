// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DataLocation
 * @author Jack Xu @ EthSign
 * @notice This enum indicates where `Schema.data` and `Attestation.data` are stored.
 */
enum DataLocation {
    ONCHAIN,
    ARWEAVE,
    IPFS,
    CUSTOM
}
