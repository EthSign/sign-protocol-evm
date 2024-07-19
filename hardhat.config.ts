import { HardhatUserConfig } from "hardhat/config";
import { config as configENV } from "dotenv";
import "@nomicfoundation/hardhat-foundry";
import "@openzeppelin/hardhat-upgrades";
import "solidity-docgen";

if (process.env.NODE_ENV !== "PRODUCTION") {
  configENV();
}

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.23",
        settings: {
          optimizer: {
            enabled: true,
            runs: 50,
          },
        },
      },
    ],
  },
  networks: {
    amoy: {
      url: "https://rpc-amoy.polygon.technology/",
      chainId: 80002,
      loggingEnabled: true,
      accounts: [process.env.PRIVATE_KEY!],
      gasPrice: 3200000000,
    },
    sepolia: {
      chainId: 11155111,
      url: `https://eth-sepolia-public.unifra.io`,
      accounts: [process.env.PRIVATE_KEY!],
    },
    polygon: {
      url: "https://polygon-rpc.com",
      chainId: 137,
      accounts: [process.env.PRIVATE_KEY!],
    },
    zetachainTestnet: {
      chainId: 7001,
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      accounts: [process.env.PRIVATE_KEY!],
    },
    zetachain: {
      chainId: 7000,
      url: "https://zetachain-evm.blockpi.network/v1/rpc/public",
      accounts: [process.env.PRIVATE_KEY!],
    },
    opBnbTestnet: {
      chainId: 5611,
      url: "https://opbnb-testnet-rpc.bnbchain.org",
      accounts: [process.env.PRIVATE_KEY!],
    },
    opBnb: {
      chainId: 204,
      url: "https://opbnb-mainnet-rpc.bnbchain.org",
      accounts: [process.env.PRIVATE_KEY!],
    },
    ethereum: {
      chainId: 1,
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_ETH_API!}`,
      accounts: [process.env.PRIVATE_KEY!],
    },
    scrollSepolia: {
      chainId: 534351,
      url: "https://sepolia-rpc.scroll.io/",
      accounts: [process.env.PRIVATE_KEY!],
    },
    scroll: {
      chainId: 534352,
      url: "https://rpc.ankr.com/scroll",
      accounts: [process.env.PRIVATE_KEY!],
    },
    okxX1Testnet: {
      chainId: 195,
      url: "https://testrpc.x1.tech/",
      accounts: [process.env.PRIVATE_KEY!],
    },
    xlayerMainnet: {
      chainId: 196,
      url: "https://rpc.xlayer.tech",
      accounts: [process.env.PRIVATE_KEY!],
    },
    base: {
      chainId: 8453,
      url: "https://mainnet.base.org",
      accounts: [process.env.PRIVATE_KEY!],
    },
    baseSepolia: {
      chainId: 84532,
      url: "https://sepolia.base.org",
      accounts: [process.env.PRIVATE_KEY!],
    },
    berachainTestnet: {
      chainId: 80084,
      url: "https://bartio.rpc.berachain.com/",
      accounts: [process.env.PRIVATE_KEY!],
    },
    plumeTestnet: {
      chainId: 161221135,
      url: "https://testnet-rpc.plumenetwork.xyz/http",
      accounts: [process.env.PRIVATE_KEY!],
    },
    opSepolia: {
      chainId: 11155420,
      url: "https://sepolia.optimism.io",
      accounts: [process.env.PRIVATE_KEY!],
    },
    optimism: {
      chainId: 10,
      url: "https://mainnet.optimism.io",
      accounts: [process.env.PRIVATE_KEY!],
    },
    gnosis: {
      url: "https://rpc.gnosischain.com",
      accounts: [process.env.PRIVATE_KEY!],
    },
    chiado: {
      url: "https://rpc.chiadochain.net",
      gasPrice: 1000000000,
      accounts: [process.env.PRIVATE_KEY!],
    },
    arbitrumSepolia: {
      chainId: 421614,
      url: "https://sepolia-rollup.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY!],
    },
    degen: {
      chainId: 666666666,
      url: "https://rpc.degen.tips",
      accounts: [process.env.PRIVATE_KEY!],
    },
    cyber: {
      chainId: 7560,
      url: "https://cyber.alt.technology/",
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_KEY!,
      polygonAmoy: process.env.X1_API_KEY!,
      mantaPacific: process.env.MANTAPACIFIC_KEY!,
      mantaPacificTestnet: process.env.MANTAPACIFIC_TEST_KEY!,
      avax: process.env.SNOWTRACE_KEY!,
      sepolia: process.env.ETHERSCAN_KEY!,
      mainnet: process.env.ETHERSCAN_KEY!,
      zetachainTestnet: process.env.ZETASCAN_API_KEY!,
      zetachain: process.env.ZETASCAN_API_KEY!,
      opbnb: process.env.OPBNB_API_KEY!,
      scrollSepolia: process.env.SCROLL_API_KEY!,
      scroll: process.env.SCROLL_API_KEY!,
      x1: process.env.X1_API_KEY!,
      base: process.env.BASE_API_KEY!,
      baseSepolia: process.env.BASE_SEPOLIA_API_KEY!,
      plumeTestnet: process.env.PLUME_TESTNET_API_KEY!,
      berachainTestnet: process.env.BERACHAIN_TESTNET_API_KEY!,
      opSepolia: process.env.OP_ETHERSCAN_API_KEY!,
      optimism: process.env.OP_ETHERSCAN_API_KEY!,
      chiado: process.env.GNOSISSCAN_API_KEY!,
      gnosis: process.env.GNOSISSCAN_API_KEY!,
      arbitrum: process.env.ARBITRUM_API_KEY!,
      arbitrumSepolia: process.env.ARBITRUM_API_KEY!,
      degen: "0",
      cyber: "0",
    },
    customChains: [
      {
        network: "manta",
        chainId: 169,
        urls: {
          apiURL: "https://manta-pacific.calderaexplorer.xyz/api",
          browserURL: "https://pacific-explorer.manta.network/",
        },
      },
      {
        network: "manta_testnet",
        chainId: 3441005,
        urls: {
          apiURL: "https://pacific-explorer.testnet.manta.network/api",
          browserURL: "https://pacific-explorer.testnet.manta.network/",
        },
      },
      {
        network: "avax",
        chainId: 43114,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
          browserURL: "https://avascan.info/",
        },
      },
      {
        network: "zetachainTestnet",
        chainId: 7001,
        urls: {
          apiURL: "https://zetachain-athens-3.blockscout.com/api",
          browserURL: "https://zetachain-athens-3.blockscout.com/",
        },
      },
      {
        network: "zetachain",
        chainId: 7000,
        urls: {
          apiURL: "https://zetachain.blockscout.com/api",
          browserURL: "https://zetachain.blockscout.com/",
        },
      },
      {
        network: "opbnb",
        chainId: 204,
        urls: {
          apiURL: "https://open-platform.nodereal.io/3e6ff01181534922a576386e1880d414/op-bnb-mainnet/contract/",
          browserURL: "https://opbnbscan.com/",
        },
      },
      {
        network: "scrollSepolia",
        chainId: 534351,
        urls: {
          apiURL: "https://api-sepolia.scrollscan.com/api",
          browserURL: "https://sepolia.scrollscan.com/",
        },
      },
      {
        network: "scroll",
        chainId: 534352,
        urls: {
          apiURL: "https://api.scrollscan.com/api",
          browserURL: "https://scrollscan.com/",
        },
      },
      {
        network: "x1",
        chainId: 195,
        urls: {
          apiURL: "https://www.oklink.com/api/explorer/v1/contract/verify/async/api/x1_test",
          browserURL: "https://www.oklink.com/x1-test",
        },
      },
      {
        network: "x1",
        chainId: 196,
        urls: {
          apiURL: "https://www.oklink.com/api/v5/explorer/XLAYER/api",
          browserURL: "https://www.oklink.com/xlayer",
        },
      },
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org",
        },
      },
      {
        network: "plumeTestnet",
        chainId: 161221135,
        urls: {
          apiURL: "https://testnet-explorer.plumenetwork.xyz/api",
          browserURL: "https://testnet-explorer.plumenetwork.xyz/",
        },
      },
      {
        network: "berachainTestnet",
        chainId: 80084,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api",
          browserURL: "https://bartio.beratrail.io/",
        },
      },
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/AMOY_TESTNET",
          browserURL: "https://www.oklink.com/amoy",
        },
      },
      {
        network: "opSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimistic.etherscan.io",
        },
      },
      {
        network: "optimism",
        chainId: 10,
        urls: {
          apiURL: "https://api-optimistic.etherscan.io/api",
          browserURL: "https://explorer.optimism.io",
        },
      },
      {
        network: "chiado",
        chainId: 10200,
        urls: {
          apiURL: "https://gnosis-chiado.blockscout.com/api",
          browserURL: "https://blockscout.com/gnosis/chiado",
        },
      },
      {
        network: "gnosis",
        chainId: 100,
        urls: {
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://gnosisscan.io/",
        },
      },
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "degen",
        chainId: 666666666,
        urls: {
          apiURL: "https://explorer.degen.tips/api",
          browserURL: "https://explorer.degen.tips/",
        },
      },
      {
        network: "cyber",
        chainId: 7560,
        urls: {
          apiURL: "https://cyber-explorer.alt.technology/api",
          browserURL: "https://cyber-explorer.alt.technology/",
        },
      },
    ],
  },
  docgen: {
    pages: "files",
    exclude: ["libraries", "mock"],
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
