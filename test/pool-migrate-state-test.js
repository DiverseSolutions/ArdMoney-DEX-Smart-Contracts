const { expect } = require("chai");
const { ethers } = require("hardhat");
const { waffle } = require("hardhat");

const { 
  initializeDummyTokens,
  initializeArdMoneyContracts,
  approveToken,
  tokenMint,
} = require('./helpers.js');

describe("ArdMoney Pool State Tests", function () {
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

    await initializeMinting(tokenA,tokenB,amaraa,odko,owner)
    await createPair(router, tokenA, odko, tokenB, fakeDeadline);

    pairContract = await getPairContract(factory, pairContract);
  })

  it("getPoolState()", async function () {
    console.log(await pairContract.connect(routerAdmin).getPoolState());
  });

  it("getPoolHasBalanceAddresses()", async function () {
    console.log(await pairContract.connect(routerAdmin).getPoolHasBalanceAddresses());
  });







});







async function getPairContract(factory, pairContract) {
  let length = await factory.allPairsLength();
  let pairAddress = await factory.allPairs(length - 1);

  pairContract = await ethers.getContractAt('ArdMoneyPair', pairAddress);
  return pairContract;
}

async function createPair(router, tokenA, odko, tokenB, fakeDeadline) {
  await approveToken(router, tokenA, '100', odko);
  await approveToken(router, tokenB, '100', odko);

  await router.connect(odko).addLiquidity(
    tokenA.address,
    tokenB.address,
    ethers.utils.parseUnits('100', 18),
    ethers.utils.parseUnits('100', 18),
    1,
    1,
    odko.address,
    fakeDeadline
  );
}

async function initializeMinting(tokenA,tokenB,amaraa,odko,owner){
    await tokenMint(tokenA,'2000',amaraa.address,owner)
    await tokenMint(tokenA,'1000',odko.address,owner)
    await tokenMint(tokenB,'1000',odko.address,owner)
}
