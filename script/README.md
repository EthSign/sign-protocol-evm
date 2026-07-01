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

```bash
SP_IMPLEMENTATION=0x... \
INITIAL_SCHEMA_COUNTER=1 \
INITIAL_ATTESTATION_COUNTER=1 \
forge script script/DeploySPProxy.s.sol --rpc-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY"
```

## Existing proxy upgrade

`UpgradeSPProxies` deploys the implementation unless `SP_IMPLEMENTATION` is set, then upgrades existing UUPS proxies.

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
