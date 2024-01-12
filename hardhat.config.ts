import { HardhatUserConfig } from "hardhat/config";
import { config as configENV } from "dotenv";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-foundry";
import "@openzeppelin/hardhat-upgrades";
import "solidity-docgen";
import "hardhat-deploy";

if (process.env.NODE_ENV !== "PRODUCTION") {
  configENV();
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.23",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    mumbai: {
      url: "https://rpc.ankr.com/polygon_mumbai",
      chainId: 80001,
      loggingEnabled: true,
      accounts: [process.env.PRIVATE_KEY!],
      saveDeployments: true,
      zksync: false,
    },
    zetachain_testnet: {
      chainId: 7001,
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      accounts: [process.env.PRIVATE_KEY!],
      saveDeployments: true,
      zksync: false,
    },
  },
};

export default config;
