#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1.4"
DEFAULT_IMPL_SALT_ID="sign-protocol/SP/implementation/v${VERSION}"
UPGRADE_CALLDATA_DEFAULT="0x"
IMPLEMENTATION_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

BROADCAST=false
CHAIN_INPUT=""
RPC_URL_ARG=""
SP_PROXY_ARG=""
SP_IMPLEMENTATION_ARG=""

usage() {
    cat <<'EOF'
Patch an existing Sign Protocol SP proxy to the current implementation.

Usage:
  bun run patch:sp -- <chain-alias-or-id> [--broadcast]
  bun run patch:sp -- base
  bun run patch:sp -- base --broadcast
  bun run patch:sp -- 8453 --proxy 0x... --implementation 0x...

Required env:
  ALCHEMY_API_KEY        Used for Alchemy-supported chains.
  PRIVATE_KEY           Required only with --broadcast, or to derive DEPLOYER.

Optional env / flags:
  DEPLOYER              Defaults to cast wallet address --private-key "$PRIVATE_KEY".
  RPC_URL               Fallback RPC URL for unsupported chains.
  <CHAIN>_RPC_URL       Chain-specific fallback for unsupported chains, e.g. PLUME_TESTNET_RPC_URL.
  SP_PROXY              Overrides the address-book proxy.
  SP_IMPLEMENTATION     Uses an existing implementation instead of deploying/resolving one.
  SP_IMPL_SALT_ID       Defaults to sign-protocol/SP/implementation/v1.1.4.
  UPGRADE_CALLDATA      Defaults to 0x.

Flags:
  --broadcast           Send transactions. Without it, the script simulates only.
  --rpc-url URL         Override RPC URL.
  --proxy ADDRESS       Override SP proxy.
  --implementation ADDRESS
                        Override SP implementation.
  --list                Print supported chain aliases and proxies.
  -h, --help            Show this help.
EOF
}

list_chains() {
    cat <<'EOF'
Alias                  Chain ID     Alchemy network / RPC fallback       SP proxy
ethereum               1            eth-mainnet                         0x3D8E699Db14d7781557fE94ad99d93Be180A6594
optimism               10           opt-mainnet                         0x945C44803E92a3495C32be951052a62E45A5D964
bnb                    56           bnb-mainnet                         0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63
gnosis                 100          gnosis-mainnet                      0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
polygon                137          polygon-mainnet                     0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63
xlayer                 196          XLAYER_RPC_URL                      0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
opbnb                  204          opbnb-mainnet                       0x03688D459F172B058d39241456Ae213FC4E26941
opbnb-testnet          5611         opbnb-testnet                       0x72efA4093539A909C1f9bcCA1aE6bcDa435a3433
zetachain              7000         zetachain-mainnet                   0xBbc279ee396074aC968b459d542DEE60c6bD71C1
cyber                  7560         CYBER_RPC_URL                       0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
base                   8453         base-mainnet                        0x2b3224D080452276a76690341e5Cfa81A945a985
gnosis-chiado          10200        gnosis-chiado                       0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
arbitrum               42161        arb-mainnet                         0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
celo                   42220        celo-mainnet                        0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
celo-alfajores         44787        CELO_ALFAJORES_RPC_URL              0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
polygon-mumbai         80001        POLYGON_MUMBAI_RPC_URL              0x4665fffdD8b48aDF5bab3621F835C831f0ee36D7
polygon-amoy           80002        polygon-amoy                        0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
berachain-artio        80085        BERACHAIN_ARTIO_RPC_URL             0x2774d96a841E522549CE7ADd3825fC31075384Cf
base-sepolia           84532        base-sepolia                        0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
plume-testnet          98865        PLUME_TESTNET_RPC_URL               0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
arbitrum-sepolia       421614       arb-sepolia                         0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
scroll-sepolia         534351       scroll-sepolia                      0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
scroll                 534352       scroll-mainnet                      0xFBF614E89Ac79d738BaeF81CE6929897594b7E69
sepolia                11155111     eth-sepolia                         0x878c92FD89d8E0B93Dc0a3c907A2adc7577e39c5
optimism-sepolia       11155420     opt-sepolia                         0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
degen                  666666666    degen-mainnet                       0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

mask_url() {
    local url="$1"
    if [[ -n "${ALCHEMY_API_KEY:-}" ]]; then
        echo "${url//$ALCHEMY_API_KEY/API_KEY}"
    else
        echo "$url"
    fi
}

lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

normalize_address() {
    lower "$1"
}

# cast >= 1.x prints decoded strings wrapped in double quotes; older versions do not.
strip_quotes() {
    local value="$1"
    value="${value#\"}"
    value="${value%\"}"
    echo "$value"
}

read_proxy_version() {
    local raw
    raw="$(cast call "$SP_PROXY_RESOLVED" 'version()(string)' --rpc-url "$RPC_URL_RESOLVED")" || return 1
    strip_quotes "$raw"
}

resolve_chain() {
    local key
    key="$(lower "$1")"
    key="${key//_/-}"

    CHAIN_ID=""
    CHAIN_NAME=""
    SP_PROXY_DEFAULT=""
    ALCHEMY_NETWORK=""
    RPC_ENV_VAR=""

    case "$key" in
        1 | eth | ethereum | mainnet)
            CHAIN_ID=1; CHAIN_NAME=ethereum; ALCHEMY_NETWORK=eth-mainnet
            SP_PROXY_DEFAULT=0x3D8E699Db14d7781557fE94ad99d93Be180A6594
            ;;
        10 | op | optimism)
            CHAIN_ID=10; CHAIN_NAME=optimism; ALCHEMY_NETWORK=opt-mainnet
            SP_PROXY_DEFAULT=0x945C44803E92a3495C32be951052a62E45A5D964
            ;;
        56 | bnb | bsc)
            CHAIN_ID=56; CHAIN_NAME=bnb; ALCHEMY_NETWORK=bnb-mainnet
            SP_PROXY_DEFAULT=0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63
            ;;
        100 | gnosis | xdai)
            CHAIN_ID=100; CHAIN_NAME=gnosis; ALCHEMY_NETWORK=gnosis-mainnet
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        137 | polygon | matic)
            CHAIN_ID=137; CHAIN_NAME=polygon; ALCHEMY_NETWORK=polygon-mainnet
            SP_PROXY_DEFAULT=0xe2C15B97F628B7Ad279D6b002cEDd414390b6D63
            ;;
        196 | xlayer | x-layer | okx | okx-xlayer)
            CHAIN_ID=196; CHAIN_NAME=xlayer; RPC_ENV_VAR=XLAYER_RPC_URL
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        204 | opbnb)
            CHAIN_ID=204; CHAIN_NAME=opbnb; ALCHEMY_NETWORK=opbnb-mainnet
            SP_PROXY_DEFAULT=0x03688D459F172B058d39241456Ae213FC4E26941
            ;;
        5611 | opbnb-testnet)
            CHAIN_ID=5611; CHAIN_NAME=opbnb-testnet; ALCHEMY_NETWORK=opbnb-testnet
            SP_PROXY_DEFAULT=0x72efA4093539A909C1f9bcCA1aE6bcDa435a3433
            ;;
        7000 | zeta | zetachain)
            CHAIN_ID=7000; CHAIN_NAME=zetachain; ALCHEMY_NETWORK=zetachain-mainnet
            SP_PROXY_DEFAULT=0xBbc279ee396074aC968b459d542DEE60c6bD71C1
            ;;
        7560 | cyber)
            CHAIN_ID=7560; CHAIN_NAME=cyber; RPC_ENV_VAR=CYBER_RPC_URL
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        8453 | base)
            CHAIN_ID=8453; CHAIN_NAME=base; ALCHEMY_NETWORK=base-mainnet
            SP_PROXY_DEFAULT=0x2b3224D080452276a76690341e5Cfa81A945a985
            ;;
        10200 | chiado | gnosis-chiado)
            CHAIN_ID=10200; CHAIN_NAME=gnosis-chiado; ALCHEMY_NETWORK=gnosis-chiado
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        42161 | arb | arbitrum)
            CHAIN_ID=42161; CHAIN_NAME=arbitrum; ALCHEMY_NETWORK=arb-mainnet
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        42220 | celo)
            CHAIN_ID=42220; CHAIN_NAME=celo; ALCHEMY_NETWORK=celo-mainnet
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        44787 | alfajores | celo-alfajores)
            CHAIN_ID=44787; CHAIN_NAME=celo-alfajores; RPC_ENV_VAR=CELO_ALFAJORES_RPC_URL
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        80001 | mumbai | polygon-mumbai)
            CHAIN_ID=80001; CHAIN_NAME=polygon-mumbai; RPC_ENV_VAR=POLYGON_MUMBAI_RPC_URL
            SP_PROXY_DEFAULT=0x4665fffdD8b48aDF5bab3621F835C831f0ee36D7
            ;;
        80002 | amoy | polygon-amoy)
            CHAIN_ID=80002; CHAIN_NAME=polygon-amoy; ALCHEMY_NETWORK=polygon-amoy
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        80085 | artio | berachain-artio)
            CHAIN_ID=80085; CHAIN_NAME=berachain-artio; RPC_ENV_VAR=BERACHAIN_ARTIO_RPC_URL
            SP_PROXY_DEFAULT=0x2774d96a841E522549CE7ADd3825fC31075384Cf
            ;;
        84532 | base-sepolia)
            CHAIN_ID=84532; CHAIN_NAME=base-sepolia; ALCHEMY_NETWORK=base-sepolia
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        98865 | plume | plume-testnet)
            CHAIN_ID=98865; CHAIN_NAME=plume-testnet; RPC_ENV_VAR=PLUME_TESTNET_RPC_URL
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        421614 | arb-sepolia | arbitrum-sepolia)
            CHAIN_ID=421614; CHAIN_NAME=arbitrum-sepolia; ALCHEMY_NETWORK=arb-sepolia
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        534351 | scroll-sepolia)
            CHAIN_ID=534351; CHAIN_NAME=scroll-sepolia; ALCHEMY_NETWORK=scroll-sepolia
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        534352 | scroll)
            CHAIN_ID=534352; CHAIN_NAME=scroll; ALCHEMY_NETWORK=scroll-mainnet
            SP_PROXY_DEFAULT=0xFBF614E89Ac79d738BaeF81CE6929897594b7E69
            ;;
        11155111 | sepolia | eth-sepolia | ethereum-sepolia)
            CHAIN_ID=11155111; CHAIN_NAME=sepolia; ALCHEMY_NETWORK=eth-sepolia
            SP_PROXY_DEFAULT=0x878c92FD89d8E0B93Dc0a3c907A2adc7577e39c5
            ;;
        11155420 | op-sepolia | optimism-sepolia)
            CHAIN_ID=11155420; CHAIN_NAME=optimism-sepolia; ALCHEMY_NETWORK=opt-sepolia
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        666666666 | degen)
            CHAIN_ID=666666666; CHAIN_NAME=degen; ALCHEMY_NETWORK=degen-mainnet
            SP_PROXY_DEFAULT=0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD
            ;;
        *)
            die "unknown chain '$1'. Run with --list to see supported aliases."
            ;;
    esac
}

resolve_rpc_url() {
    if [[ -n "$RPC_URL_ARG" ]]; then
        RPC_URL_RESOLVED="$RPC_URL_ARG"
        RPC_SOURCE="--rpc-url"
        return
    fi

    if [[ -n "$RPC_ENV_VAR" ]]; then
        local chain_rpc="${!RPC_ENV_VAR:-}"
        if [[ -n "$chain_rpc" ]]; then
            RPC_URL_RESOLVED="$chain_rpc"
            RPC_SOURCE="$RPC_ENV_VAR"
            return
        fi
    fi

    if [[ -n "$ALCHEMY_NETWORK" ]]; then
        [[ -n "${ALCHEMY_API_KEY:-}" ]] || die "ALCHEMY_API_KEY is required for $CHAIN_NAME"
        RPC_URL_RESOLVED="https://${ALCHEMY_NETWORK}.g.alchemy.com/v2/${ALCHEMY_API_KEY}"
        RPC_SOURCE="Alchemy ${ALCHEMY_NETWORK}"
        return
    fi

    if [[ -n "${RPC_URL:-}" ]]; then
        RPC_URL_RESOLVED="$RPC_URL"
        RPC_SOURCE="RPC_URL"
        return
    fi

    if [[ -n "$RPC_ENV_VAR" ]]; then
        die "$CHAIN_NAME is not configured for Alchemy. Set $RPC_ENV_VAR or pass --rpc-url."
    fi
    die "no RPC URL resolved for $CHAIN_NAME"
}

resolve_deployer() {
    if [[ -n "${DEPLOYER:-}" ]]; then
        DEPLOYER_RESOLVED="$DEPLOYER"
        return
    fi
    [[ -n "${PRIVATE_KEY:-}" ]] || die "DEPLOYER is unset and PRIVATE_KEY is unavailable"
    DEPLOYER_RESOLVED="$(cast wallet address --private-key "$PRIVATE_KEY")"
}

forge_common_env() {
    export DEPLOYER="$DEPLOYER_RESOLVED"
    export SP_IMPL_SALT_ID="${SP_IMPL_SALT_ID:-$DEFAULT_IMPL_SALT_ID}"
    export UPGRADE_CALLDATA="${UPGRADE_CALLDATA:-$UPGRADE_CALLDATA_DEFAULT}"
    if [[ "$BROADCAST" == true && -z "${ALLOWED_DEPLOYMENT_SENDER:-}" ]]; then
        export ALLOWED_DEPLOYMENT_SENDER="$DEPLOYER_RESOLVED"
    fi
}

run_forge_script() {
    local script_path="$1"
    local target_contract="$2"
    shift 2

    local cmd=(forge script "$script_path" --tc "$target_contract" --rpc-url "$RPC_URL_RESOLVED")
    if [[ "$BROADCAST" == true ]]; then
        [[ -n "${PRIVATE_KEY:-}" ]] || die "PRIVATE_KEY is required with --broadcast"
        cmd+=(--broadcast --private-key "$PRIVATE_KEY")
    fi

    "${cmd[@]}" "$@"
}

deploy_implementation_for_safe() {
    local log_file
    log_file="$(mktemp "${TMPDIR:-/tmp}/sp-impl-deploy.XXXXXX.log")"

    echo "Deploying/resolving SP implementation for Safe/contract-owner upgrade..."
    export ALLOWED_DEPLOYMENT_SENDER="${ALLOWED_DEPLOYMENT_SENDER:-$DEPLOYER_RESOLVED}"
    run_forge_script script/DeploySPImplementation.s.sol DeploySPImplementation 2>&1 | tee "$log_file"

    local implementation=""
    implementation="$(grep -E 'SPImplementation (deployed|already deployed) at 0x[0-9a-fA-F]{40}' "$log_file" | tail -n 1 | awk '{print $NF}' || true)"
    if [[ -z "$implementation" && -f "deployments/sp/${CHAIN_ID}-latest.json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            implementation="$(jq -r '.SPImplementation // empty' "deployments/sp/${CHAIN_ID}-latest.json" || true)"
        else
            implementation="$(sed -n 's/.*"SPImplementation"[[:space:]]*:[[:space:]]*"\(0x[0-9a-fA-F]\{40\}\)".*/\1/p' "deployments/sp/${CHAIN_ID}-latest.json" | tail -n 1 || true)"
        fi
    fi

    rm -f "$log_file"
    [[ -n "$implementation" ]] || die "could not determine SP implementation address from deploy output"
    SP_IMPLEMENTATION_RESOLVED="$implementation"
}

print_safe_upgrade() {
    local implementation="$1"
    local data implementation_suffix
    data="$(cast calldata 'upgradeToAndCall(address,bytes)' "$implementation" "$UPGRADE_CALLDATA_RESOLVED")"
    implementation_suffix="$(lower "${implementation#0x}")"

    cat <<EOF

Proxy owner is not the deployment signer, so no direct UUPS upgrade was attempted.
Submit this transaction through the proxy owner:

  To:    $SP_PROXY_RESOLVED
  Value: 0
  Data:  $data

Implementation: $implementation

After the owner executes it, verify with:

  cast storage $SP_PROXY_RESOLVED $IMPLEMENTATION_SLOT --rpc-url <RPC_URL>   # must end with $implementation_suffix
  cast call $SP_PROXY_RESOLVED 'version()(string)' --rpc-url <RPC_URL>       # must return $VERSION
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --list)
            list_chains
            exit 0
            ;;
        --broadcast)
            BROADCAST=true
            shift
            ;;
        --rpc-url)
            [[ $# -ge 2 ]] || die "--rpc-url requires a value"
            RPC_URL_ARG="$2"
            shift 2
            ;;
        --proxy)
            [[ $# -ge 2 ]] || die "--proxy requires a value"
            SP_PROXY_ARG="$2"
            shift 2
            ;;
        --implementation)
            [[ $# -ge 2 ]] || die "--implementation requires a value"
            SP_IMPLEMENTATION_ARG="$2"
            shift 2
            ;;
        -*)
            die "unknown flag '$1'"
            ;;
        *)
            [[ -z "$CHAIN_INPUT" ]] || die "multiple chain values provided: '$CHAIN_INPUT' and '$1'"
            CHAIN_INPUT="$1"
            shift
            ;;
    esac
done

[[ -n "$CHAIN_INPUT" ]] || die "missing chain. Run with --help or --list."

resolve_chain "$CHAIN_INPUT"
resolve_rpc_url
resolve_deployer
forge_common_env

SP_PROXY_RESOLVED="${SP_PROXY_ARG:-${SP_PROXY:-$SP_PROXY_DEFAULT}}"
SP_IMPLEMENTATION_RESOLVED="${SP_IMPLEMENTATION_ARG:-${SP_IMPLEMENTATION:-}}"
UPGRADE_CALLDATA_RESOLVED="${UPGRADE_CALLDATA:-$UPGRADE_CALLDATA_DEFAULT}"

[[ "$SP_PROXY_RESOLVED" =~ ^0x[0-9a-fA-F]{40}$ ]] || die "invalid SP proxy address: $SP_PROXY_RESOLVED"
if [[ -n "$SP_IMPLEMENTATION_RESOLVED" ]]; then
    [[ "$SP_IMPLEMENTATION_RESOLVED" =~ ^0x[0-9a-fA-F]{40}$ ]] || die "invalid SP implementation address: $SP_IMPLEMENTATION_RESOLVED"
fi

echo "Chain:       $CHAIN_NAME ($CHAIN_ID)"
echo "RPC source:  $RPC_SOURCE"
echo "RPC URL:     $(mask_url "$RPC_URL_RESOLVED")"
echo "Proxy:       $SP_PROXY_RESOLVED"
echo "Deployer:    $DEPLOYER_RESOLVED"
echo "Mode:        $([[ "$BROADCAST" == true ]] && echo broadcast || echo simulation)"

ACTUAL_CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL_RESOLVED")"
[[ "$ACTUAL_CHAIN_ID" == "$CHAIN_ID" ]] || die "RPC chain ID mismatch: expected $CHAIN_ID, got $ACTUAL_CHAIN_ID"

PROXY_CODE="$(cast code "$SP_PROXY_RESOLVED" --rpc-url "$RPC_URL_RESOLVED")"
[[ "$PROXY_CODE" != "0x" ]] || die "no code at SP proxy $SP_PROXY_RESOLVED on chain $CHAIN_ID"

OWNER="$(cast call "$SP_PROXY_RESOLVED" 'owner()(address)' --rpc-url "$RPC_URL_RESOLVED")"
CURRENT_VERSION="$(read_proxy_version 2>/dev/null || echo unknown)"

echo "Owner:       $OWNER"
echo "Version:     $CURRENT_VERSION"

if [[ "$(normalize_address "$OWNER")" != "$(normalize_address "$DEPLOYER_RESOLVED")" ]]; then
    if [[ -z "$SP_IMPLEMENTATION_RESOLVED" ]]; then
        if [[ "$BROADCAST" == true ]]; then
            deploy_implementation_for_safe
        else
            echo
            echo "Proxy owner is not DEPLOYER. Re-run with --broadcast to deploy the implementation,"
            echo "or pass --implementation 0x... to print Safe calldata without deploying."
            exit 0
        fi
    fi
    print_safe_upgrade "$SP_IMPLEMENTATION_RESOLVED"
    exit 0
fi

export SP_PROXY="$SP_PROXY_RESOLVED"
if [[ -n "$SP_IMPLEMENTATION_RESOLVED" ]]; then
    export SP_IMPLEMENTATION="$SP_IMPLEMENTATION_RESOLVED"
else
    unset SP_IMPLEMENTATION
fi

echo
echo "Running UUPS upgrade script..."
run_forge_script script/UpgradeSPProxies.s.sol UpgradeSPProxies

if [[ "$BROADCAST" == true ]]; then
    NEW_VERSION="$(read_proxy_version)"
    RAW_IMPL="$(cast storage "$SP_PROXY_RESOLVED" "$IMPLEMENTATION_SLOT" --rpc-url "$RPC_URL_RESOLVED")"
    echo
    echo "Post-upgrade version:        $NEW_VERSION"
    echo "Post-upgrade impl slot raw:  $RAW_IMPL"
    [[ "$NEW_VERSION" == "$VERSION" ]] || die "post-upgrade version mismatch: expected $VERSION, got $NEW_VERSION"
fi

echo
echo "Patch flow complete."
