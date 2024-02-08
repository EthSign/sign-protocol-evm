import { ethers, upgrades } from "hardhat";

async function main() {
  const SP = await ethers.getContractFactory("SP");
  const sp = await upgrades.deployProxy(SP, [1, 1]);
  await sp.waitForDeployment();
  console.log("SP deployed to:", await sp.getAddress());
}

main();
