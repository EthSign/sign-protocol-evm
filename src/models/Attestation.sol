// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Attestation {
    bytes32 schemaId;
    address attester;
    address recipient;
    uint64 validUntil;
    bool revoked;
}
