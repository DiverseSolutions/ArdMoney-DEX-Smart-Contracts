const { expect } = require("chai");
const { ethers } = require("hardhat");
const { 
  initializeArdMoneyFactoryDiamond,
  initializeArdMoneyRouterDiamond,
  initializeDummyTokens,
  approveToken,
  tokenMint,
} = require('../helpers.js');

describe("ArdMoney Router Diamond", function () {
  let owner,feeSetter,pairAdmin,odko,amaraa;

  let factoryDiamond,createPairFacet,factoryUtilityFacet,pausibleFacet,accessControlFacet,migratePairFacet,factoryAdminFacet;
  let routerDiamond, routerSwapFacet, routerLiquidityFacet, routerUtilityFacet;
  let token0,token1;

  const fakeDeadline = 2648035579;

  this.beforeEach(async function () {
    [owner,feeSetter,pairAdmin,odko,amaraa] = await ethers.getSigners();

    [
      factoryDiamond,
      createPairFacet,
      factoryUtilityFacet,
      pausibleFacet,
      accessControlFacet,
      migratePairFacet,
      factoryAdminFacet
    ] = await initializeArdMoneyFactoryDiamond(owner,feeSetter);


    [token0,token1] = await initializeDummyTokens()

    const WETH9Mock = await ethers.getContractFactory("WETH9Mock");
    const wETHContract = await WETH9Mock.deploy();
    await wETHContract.deployed();

    [
      routerDiamond,
      routerSwapFacet,
      routerLiquidityFacet,
      routerUtilityFacet,
    ] = await initializeArdMoneyRouterDiamond(owner,factoryDiamond.address,wETHContract.address);

    // 100% == 1000 || 3% == 30 || 0.3% == 3
    let swapFee = 3;
    let protocolFee = 3;

    let tx = await createPairFacet.createPair(token0.address,token1.address,swapFee,protocolFee,pairAdmin.address);
    let receipt = await tx.wait()

  });

  it("Router - Add Liqudity", async function () {
    await tokenMint(token0,'2000',odko.address,owner)
    await tokenMint(token1,'2000',odko.address,owner)

    await approveToken(routerDiamond,token0,'500',odko)
    await approveToken(routerDiamond,token1,'500',odko)

    await routerLiquidityFacet.connect(odko).addLiquidity(
      token0.address,
      token1.address,
      ethers.utils.parseUnits('500',18),
      ethers.utils.parseUnits('500',18),
      1,
      1,
      odko.address,
      fakeDeadline
    )

  });


  it("Router - ExactTokensForTokens Swap", async function () {
    await tokenMint(token0,'2000',odko.address,owner)
    await tokenMint(token1,'2000',odko.address,owner)

    await approveToken(routerDiamond,token0,'500',odko)
    await approveToken(routerDiamond,token1,'500',odko)

    await routerLiquidityFacet.connect(odko).addLiquidity(
      token0.address,
      token1.address,
      ethers.utils.parseUnits('500',18),
      ethers.utils.parseUnits('500',18),
      1,
      1,
      odko.address,
      fakeDeadline
    )

    await tokenMint(token0,'2000',amaraa.address,owner)
    await approveToken(routerDiamond,token0,'100',amaraa)

    let amountInWei = ethers.utils.parseEther('100',18)
    let path = [token0.address,token1.address]

    let [,amountsOutWei] = await routerUtilityFacet.getAmountsOut(amountInWei,path)

    await routerSwapFacet.connect(amaraa).swapExactTokensForTokens(
      amountInWei,
      1,
      path,
      amaraa.address,
      fakeDeadline
    )

    let amaraaBalance = await token1.balanceOf(amaraa.address)

    expect(amaraaBalance).to.equal(amountsOutWei);

  });

});

