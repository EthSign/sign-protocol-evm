// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

enum DataLocation {
    ONCHAIN,
    ARWEAVE,
    IPFS,
    CUSTOM
}

struct URIPointer {
    DataLocation dataLocation;
    string uri;
}
