# Changelog

All notable changes to this package are documented here.

## 1.1.4

- Hardened delegated signatures with EIP-712 domain binding, per-attester nonces, and deadlines.
- Added `delegationNonces(address)` and `getDelegatedAuthorizationDigest(...)` for delegated-action signing.
- Rejected legacy delegated signatures that do not use the new encoded `(nonce, deadline, signature)` format.
- Converted deployment and upgrade tooling from Hardhat scripts to Foundry scripts using the CREATE3 deployment template.
- Added deterministic SP implementation deployment and existing proxy upgrade scripts.
- Added `bun run patch:sp` for chain-aware proxy patching with Alchemy RPC URL derivation.
- Added optional proxy ownership transfer to `PROD_OWNER` after successful upgrades.
- Added standard JSON input for SP `1.1.4` contract verification.
- Removed legacy Hardhat, Prettier, and unused package tooling in favor of Bun and Foundry formatting.

## 1.1.3

- Removed `registerBatch` and related interface functions to reduce contract size.
- Added Soldeer support and refreshed Foundry dependency wiring.
- Added Monad testnet configuration and deployment metadata updates.

## 1.1.2

- Fixed linked-attestation validation behavior.
- Added missing revoked-attestation checks while attesting.
- Bumped the Solidity compiler configuration to `0.8.26`.

## 1.1.1

- Fixed schema existence checks.

## 1.1.0

- Added storage of schema and attestation timestamps.
- Added backward-compatible behavior for existing schema and attestation counters.
- Optimized SP core contract and interface types.

## 1.0.1

- Fixed incorrect data passed to hooks.

## 1.0.0

- Initial npm package release for Sign Protocol EVM contracts.
