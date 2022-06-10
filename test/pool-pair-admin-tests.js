const { expect } = require("chai");
const { ethers } = require("hardhat");
const { waffle } = require("hardhat");

const { 
  initializeDummyTokens,
  initializeArdMoneyContracts,
  approveToken,
  tokenMint,
} = require('./helpers.js');

describe("ArdMoney Pair Contract Admin Tests", function () {
  const fakeDeadline = 2648035579;

  let owner,odko,amaraa,feeSetter,routerAdmin;
  let factory,router,weth;
  let pairContract;
  let tokenA,tokenB;

  // 100% == 1000 || 3% == 30 || 0.3% == 3
  let swapFee;
  let mintFee;

  this.beforeEach(async function (){
    [owner,odko,amaraa,feeSetter,routerAdmin] = await ethers.getSigners();

    swapFee = 3;
    mintFee = 2;

    [ factory,router,weth ] = await initializeArdMoneyContracts( feeSetter.address, routerAdmin.address, swapFee, mintFee);
    [ tokenA,tokenB ] = await initializeDummyTokens();

    await tokenMint(tokenA,'2000',amaraa.address,owner)

    await tokenMint(tokenA,'1000',odko.address,owner)
    await tokenMint(tokenB,'1000',odko.address,owner)

    // Create Liquidity
    await approveToken(router,tokenA,'100',odko)
    await approveToken(router,tokenB,'100',odko)

    await router.connect(odko).addLiquidity(
      tokenA.address,
      tokenB.address,
      ethers.utils.parseUnits('100',18),
      ethers.utils.parseUnits('100',18),
      1,
      1,
      odko.address,
      fakeDeadline 
    )

    let length = await factory.allPairsLength();
    let pairAddress = await factory.allPairs(length-1);

    pairContract = await ethers.getContractAt('ArdMoneyPair',pairAddress)

  })

  it("Get Functionalities Test", async function () {
    expect(await pairContract.getAdmin()).to.equal(routerAdmin.address);
    expect(await pairContract.getSwapFee()).to.equal(3);
    expect(await pairContract.getMintFee()).to.equal(2);
  });

  it("Set Functionalities Revert Test", async function () {
    expect(pairContract.connect(odko).setMintFee(5))
      .to.be.revertedWith("You need to be an admin to make changes");

    expect(pairContract.connect(odko).setMintFee(5))
      .to.be.revertedWith("You need to be an admin to make changes");

    expect(pairContract.connect(odko).setAdmin(odko.address))
      .to.be.revertedWith("You need to be an admin to make changes");
    

    revertCheck(pairContract.connect(odko).setAdmin(odko.address),"You need to be an admin to make changes")

  });

  it("Set Functionalities Test", async function () {
    await (await pairContract.connect(routerAdmin).setMintFee(4)).wait();
    await (await pairContract.connect(routerAdmin).setSwapFee(5)).wait();
    await (await pairContract.connect(routerAdmin).setAdmin(odko.address)).wait();

    expect(await pairContract.getAdmin()).to.equal(odko.address);
    expect(await pairContract.getMintFee()).to.equal(4);
    expect(await pairContract.getSwapFee()).to.equal(5);
  });

});


