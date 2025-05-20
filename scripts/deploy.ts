import "@nomicfoundation/hardhat-verify";
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const OneTimePurchaseFactory =
    await ethers.getContractFactory("OneTimePurchase");
  const OneTimePurchase = await OneTimePurchaseFactory.deploy();
  const OneTimePurchaseAddress = await OneTimePurchase.getAddress();
  console.log("OneTimePurchase deployed to:", OneTimePurchaseAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
