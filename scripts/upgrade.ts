import { ethers, upgrades } from "hardhat";

async function main() {
  const SP = await ethers.getContractFactory("SP");
  const sp = await upgrades.upgradeProxy("0xEadFcE1eA8c2BB0DE3Cc3854076E1900373Aae59", SP);
  await sp.waitForDeployment();
}

main();
