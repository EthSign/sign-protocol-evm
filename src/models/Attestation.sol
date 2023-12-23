// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Attestation {
    string schemaId;
    string linkedAttestationId;
    address attester;
    uint64 validUntil;
    bool revoked;
    address[] recipients;
}
