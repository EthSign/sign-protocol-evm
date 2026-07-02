# Sign Protocol Foundry Deployment

This repo uses Foundry scripts for deterministic Sign Protocol deployments.

## Deterministic implementation deployment

`DeploySPImplementation` deploys `SP` through CreateX CREATE3 using `SP_IMPL_SALT_ID`. Use the same `DEPLOYER` and
`SP_IMPL_SALT_ID` on each chain to get the same implementation address when bytecode is identical.

```bash
DEPLOYER=0x... \
PROD_OWNER=0x... \
MAINNET_CHAIN_IDS=1,56,100,137,8453,42161,42220,534352 \
ALLOWED_DEPLOYMENT_SENDER=0x... \
forge script script/DeploySPImplementation.s.sol --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY"
```

## Fresh proxy deployment

`DeploySPProxy` deploys the implementation unless `SP_IMPLEMENTATION` is set, then deploys an `ERC1967Proxy` through
CREATE3 and initializes it with `SP.initialize(INITIAL_SCHEMA_COUNTER, INITIAL_ATTESTATION_COUNTER)`.

If `PROD_OWNER` is set, the script transfers proxy ownership to that address even when the chain is not listed in
`MAINNET_CHAIN_IDS`. If the chain is listed in `MAINNET_CHAIN_IDS`, `PROD_OWNER` is required.

```bash
SP_IMPLEMENTATION=0x... \
PROD_OWNER=0x... \
INITIAL_SCHEMA_COUNTER=1 \
INITIAL_ATTESTATION_COUNTER=1 \
forge script script/DeploySPProxy.s.sol --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY"
```

## Existing proxy upgrade

`UpgradeSPProxies` deploys the implementation unless `SP_IMPLEMENTATION` is set, then upgrades existing UUPS proxies.

For the normal patch flow, use the wrapper script so RPC URLs, official proxy addresses, and Foundry env are derived from
one chain alias:

```bash
cp .env.example .env
# Fill PRIVATE_KEY and ALCHEMY_API_KEY in .env.
bun run patch:sp -- base
```

Add `--broadcast` after the simulation succeeds:

```bash
bun run patch:sp -- base --broadcast
```

Run `bun run patch:sp -- --list` for supported aliases. Alchemy-supported chains are resolved from
`ALCHEMY_API_KEY`; chains that are not available through Alchemy require their chain-specific RPC env var, such as
`PLUME_TESTNET_RPC_URL`, or `--rpc-url`. The wrapper loads `.env` automatically by default; set `ENV_FILE=/path/to/env`
to load a different file.

If the proxy owner is not the deployment signer, the wrapper does not attempt a direct upgrade. With `--broadcast`, it
deploys or resolves the implementation and prints the `upgradeToAndCall(implementation, 0x)` calldata to submit through
the owner contract or Safe.

Existing proxy upgrades do not transfer ownership by default. To transfer a deployer-owned proxy to `PROD_OWNER` after a
successful upgrade, set both:

```bash
TRANSFER_PROXY_OWNER=true
PROD_OWNER=0x...
```

To upgrade one explicit proxy:

```bash
SP_PROXY=0x... \
SP_IMPLEMENTATION=0x... \
forge script script/UpgradeSPProxies.s.sol --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY"
```

To upgrade the official active proxy for the current `block.chainid`, set:

```bash
UPGRADE_ALL_KNOWN_PROXIES=true
```

The batch registry follows the official address book at https://docs.sign.global/for-builders/address-book and excludes
deprecated, struck-through entries. Use `SP_PROXY` if a non-address-book or deprecated proxy should be upgraded.

If the new implementation has a reinitializer, pass its calldata through `UPGRADE_CALLDATA`.

The upgrade script verifies that the proxy's ERC-1967 implementation slot is updated and that `version()` returns
`SP_EXPECTED_VERSION`. If `SP_EXPECTED_VERSION` is unset, the script uses the resolved implementation's `version()`;
an unreadable or empty implementation/proxy `version()` is rejected.
