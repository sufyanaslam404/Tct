const { ethers, run } = require("hardhat");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();

    console.log("Deploying contracts with the account:", deployer.address);

    const balance = await deployer.getBalance();
    const balanceInEther = ethers.utils.formatEther(balance);
    console.log("Account balance:", balanceInEther);

    const block = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const timestamp = block.timestamp;

    const blockchainInfo = {
      name: network.name,
      chainId: network.chainId,
      blockNumber: block.number,
      timestamp: timestamp,
    };

    console.log("Blockchain Info:");
    console.table(blockchainInfo);
    // constructor Arguments
    // const A = "0xE53Db6E9699f990cfa7Ebe64Cb2B2Bb3dbC4cD15";

    const GLDToken = await ethers.getContractFactory("GLDToken");
    const token = await GLDToken.deploy();
    await token.deployed();

    console.log("Contract address:", token.address);

    if (network.name !== "hardhat") {
      console.log("Verifying contract on the network...");
      await verifyContract(token.address, );   // Pass the actual values here A
      console.log("Contract verified on the network!");
    }
  } catch (error) {
    console.error("An error occurred:", error);
  }
}

async function verifyContract(contractAddress, A) {
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [],  // Pass the actual values here A
    });
  } catch (error) {
    console.error("Failed to verify contract on the network:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
