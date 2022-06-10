const { expect } = require("chai");
const { ethers } = require("hardhat");
const { 
  initializeArdMoneyFactoryDiamond,
  initializeDummyTokens,
} = require('../helpers.js');

describe("ArdMoney Factory Diamond", function () {
  let owner,feeSetter,pairAdmin;

  let factoryDiamond,createPairFacet,factoryUtilityFacet,pausibleFacet,accessControlFacet,migratePairFacet;
  let token0,token1;

  this.beforeEach(async function () {
    [owner,feeSetter,pairAdmin] = await ethers.getSigners();

    [
      factoryDiamond,
      createPairFacet,
      factoryUtilityFacet,
      pausibleFacet,
      accessControlFacet,
      migratePairFacet,
    ] = await initializeArdMoneyFactoryDiamond(owner,feeSetter);

    [token0,token1] = await initializeDummyTokens()
  });





  it("Testing Basic Factory - Create Pair Facet", async function () {
    // 100% == 1000 || 3% == 30 || 0.3% == 3
    let swapFee = 3;
    let protocolFee = 3;

    let tx = await createPairFacet.createPair(token0.address,token1.address,swapFee,protocolFee,pairAdmin.address);
    let receipt = await tx.wait()

    expect(receipt.events.find((i) => i.event == 'PairCreated') != undefined).to.equal(true);
    expect(await factoryUtilityFacet.allPairsLength()).to.equal(1);
  });





  it("Testing Factory Pausible Facet", async function () {
    await pausibleFacet.pause();
    await expect(createPairFacet.createPair(token0.address,token1.address,3,3,pairAdmin.address))
      .to.be.revertedWith('FACTORY PAUSED')

    expect(await pausibleFacet.paused()).to.equal(true);
  });





  it("Testing Factory Migrate Pair Facet - Remove Pair", async function () {
    let tx = await createPairFacet.createPair(token0.address,token1.address,3,3,pairAdmin.address);
    await tx.wait()

    expect(await factoryUtilityFacet.allPairsLength()).to.equal(1);

    let pair = await factoryUtilityFacet.getPair(token0.address,token1.address)
    await migratePairFacet.removePair(pair)

    expect(await factoryUtilityFacet.allPairsLength()).to.equal(0);
  });





});

