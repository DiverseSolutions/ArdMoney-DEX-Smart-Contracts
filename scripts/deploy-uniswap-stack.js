const path = require('path');
const hre = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();
  const wrappedETH = "0x86652c1301843B4E06fBfbBDaA6849266fb2b5e7"

  const Factory = await hre.ethers.getContractFactory("UniswapV2Factory");
  const factoryContract = await Factory.deploy(owner.address);

  const Router = await hre.ethers.getContractFactory("UniswapV2Router02");
  const routerContract = await Router.deploy(factoryContract.address,wrappedETH);

  await factoryContract.deployed();
  await routerContract.deployed();

  console.log("factoryContract deployed to:", factoryContract.address);
  console.log("routerContract deployed to:", routerContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


