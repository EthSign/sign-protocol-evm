import { ethers, upgrades } from "hardhat";

async function main() {
  const SP = await ethers.getContractFactory("SP");
  const sp = await upgrades.upgradeProxy("0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD", SP);
  await sp.waitForDeployment();
}

main();
