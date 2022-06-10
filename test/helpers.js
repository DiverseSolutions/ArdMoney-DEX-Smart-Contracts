const { ethers } = require("hardhat");
const { expect } = require("chai");
const { getSelectors, FacetCutAction } = require('../diamond-helpers')

async function initializeArdMoneyFactoryDiamond(contractOwner,feeSetter){
  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
  const diamondCutFacet = await DiamondCutFacet.deploy()
  await diamondCutFacet.deployed()

  const ArdMoneyFactoryDiamond = await ethers.getContractFactory("ArdMoneyFactoryDiamond");
  const ardMoneyFactoryDiamond = await ArdMoneyFactoryDiamond.deploy(contractOwner.address,diamondCutFacet.address);
  await ardMoneyFactoryDiamond.deployed();

  const DiamondInit = await ethers.getContractFactory('FactoryDiamondInit')
  const factoryDiamondInit = await DiamondInit.deploy()
  await factoryDiamondInit.deployed()

  const FacetNames = [
    'DiamondLoupeFacet',
    'OwnershipFacet',
    'BasicFactoryCreatePairFacet',
    'FactoryUtilityFacet',
    'FactoryPausibleFacet',
    'FactoryAccessControlFacet',
    'FactoryMigratePairFacet'
  ]
  const cut = []
  for (let FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName)
    const facet = await Facet.deploy()
    await facet.deployed()

    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    })
  }

  const diamondCut = await ethers.getContractAt('IDiamondCut', ardMoneyFactoryDiamond.address)

  let functionCall = factoryDiamondInit.interface.encodeFunctionData('init',[feeSetter.address])
  await (await diamondCut.diamondCut(cut, factoryDiamondInit.address, functionCall)).wait()

  const basicFactoryCreatePairFacet = await ethers.getContractAt('BasicFactoryCreatePairFacet', ardMoneyFactoryDiamond.address)
  const factoryUtilityFacet = await ethers.getContractAt('FactoryUtilityFacet', ardMoneyFactoryDiamond.address)
  const factoryPausibleFacet = await ethers.getContractAt('FactoryPausibleFacet', ardMoneyFactoryDiamond.address)

  const accessControlFacet = await ethers.getContractAt('FactoryAccessControlFacet', ardMoneyFactoryDiamond.address)
  const migratePairFacet = await ethers.getContractAt('FactoryMigratePairFacet', ardMoneyFactoryDiamond.address)

  return [ 
    ardMoneyFactoryDiamond, 
    basicFactoryCreatePairFacet, 
    factoryUtilityFacet,
    factoryPausibleFacet,

    accessControlFacet,
    migratePairFacet
  ] 
}

async function initializeDummyTokens(){
  const DummyTokenA = await ethers.getContractFactory("DummyTokenA");
  const dummyTokenAContract = await DummyTokenA.deploy();
  await dummyTokenAContract.deployed();

  const DummyTokenB = await ethers.getContractFactory("DummyTokenB");
  const dummyTokenBContract = await DummyTokenB.deploy();
  await dummyTokenBContract.deployed();

  return [dummyTokenAContract,dummyTokenBContract] 
}

async function initializeArdMoneyContracts(feeSetterAddress,routerAdminAddress,swapFee,mintFee){
  const WETH9Mock = await ethers.getContractFactory("WETH9Mock");
  const wETHContract = await WETH9Mock.deploy();
  await wETHContract.deployed();

  const ArdMoneyFactory = await ethers.getContractFactory("ArdMoneyFactory");
  const ardMoneyFactoryContract = await ArdMoneyFactory.deploy(feeSetterAddress);
  await ardMoneyFactoryContract.deployed();

  const ArdMoneyRouter = await ethers.getContractFactory("ArdMoneyRouter");
  const ardMoneyRouterContract = await ArdMoneyRouter.deploy(
    ardMoneyFactoryContract.address,
    wETHContract.address,
    routerAdminAddress,
    swapFee,
    mintFee,
  );

  await ardMoneyRouterContract.deployed();

  return [ardMoneyFactoryContract,ardMoneyRouterContract,wETHContract]
}

async function approveToken(router,token,amount,account){
  let oldAllowance = await token.allowance(account.address,router.address)
  let decimals = await token.decimals()
  let amountWei = ethers.utils.parseEther(amount,decimals)

  await ( await token.connect(account).approve(router.address,amountWei) ).wait()

  let newAllowance = await token.allowance(account.address,router.address)
  let amountToAddWEI = ethers.utils.parseUnits(amount,decimals)

  expect(oldAllowance.add(amountToAddWEI)).to.equal(newAllowance);
}

async function tokenMint(token,amount,to,owner){
  let oldBalance = await token.balanceOf(to)
  let decimals = await token.decimals()
  let amountWei = ethers.utils.parseEther(amount,decimals)

  await ( await token.connect(owner).mint(to,amountWei) ).wait()

  let newBalance = await token.balanceOf(to)
  let amountToAddWEI = ethers.utils.parseUnits(amount,decimals)

  expect(oldBalance.add(amountToAddWEI)).to.equal(newBalance);
}


module.exports = {
  initializeArdMoneyFactoryDiamond,

  initializeDummyTokens,
  initializeArdMoneyContracts,
  approveToken,
  tokenMint,
}
