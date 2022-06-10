const { expect } = require("chai");
const { ethers } = require("hardhat");
const { 
  initializeDummyTokens,
  initializeArdMoneyContracts,
  approveToken,
  tokenMint,
} = require('./helpers.js');

describe("ArdMoney Swap Dynamic Pool", function () {
  const fakeDeadline = 2648035579;

  let owner,odko,amaraa,feeSetter,routerAdmin;
  let factory,router,weth;
  let tokenA,tokenB;

  // 100% == 1000 || 3% == 30 || 0.3% == 3
  let swapFee;
  let mintFee;

  this.beforeEach(async function (){
    [owner,odko,amaraa,feeSetter,routerAdmin] = await ethers.getSigners();

    swapFee = 3;
    mintFee = 3;

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

  })

  it("Swap Dynamic Pool", async function () {

    await approveToken(router,tokenA,'100',amaraa)
    let amountInWei = ethers.utils.parseEther('100',18)
    let path = [tokenA.address,tokenB.address]

    let [,amountsOutWei] = await router.getAmountsOut(amountInWei,path)

    await router.connect(amaraa).swapExactTokensForTokens(
      amountInWei,
      1,
      path,
      amaraa.address,
      fakeDeadline
    )

    let amaraaBalance = await tokenB.balanceOf(amaraa.address)

    expect(amaraaBalance).to.equal(amountsOutWei);
  });

});


