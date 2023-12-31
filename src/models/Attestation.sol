// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Attestation {
    uint256 schemaId;
    uint256 linkedAttestationId;
    address attester;
    uint64 validUntil;
    bool revoked;
    address[] recipients;
    bytes data;
}

struct OffchainAttestation {
    address attester;
    uint64 timestamp;
}
