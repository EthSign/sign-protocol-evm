import { Deployer } from "@matterlabs/hardhat-zksync";
import { Wallet } from "zksync-ethers";

import * as hre from "hardhat";

async function main() {
  const contractName = "SP";
  console.log("Deploying " + contractName + "...");
  const zkWallet = new Wallet(process.env.PRIVATE_KEY!);
  const deployer = new Deployer(hre, zkWallet);
  const contract = await deployer.loadArtifact(contractName);
  const instance = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, [1, 1], { initializer: "initialize" });
  await instance.waitForDeployment();
  console.log(contractName + " deployed to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
