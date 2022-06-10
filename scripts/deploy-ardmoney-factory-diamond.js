const { getSelectors, FacetCutAction } = require('../diamond-helpers')

async function deployDiamond () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]
  const feeSetter = accounts[0]
  const pairAdmin = accounts[0]

  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
  const diamondCutFacet = await DiamondCutFacet.deploy()
  await diamondCutFacet.deployed()
  console.log('DiamondCutFacet - ',diamondCutFacet.address)

  const ArdMoneyFactoryDiamond = await ethers.getContractFactory("ArdMoneyFactoryDiamond");
  const ardMoneyFactoryDiamond = await ArdMoneyFactoryDiamond.deploy(contractOwner.address,diamondCutFacet.address);
  await ardMoneyFactoryDiamond.deployed();
  console.log('FactoryDiamond - ',ardMoneyFactoryDiamond.address)

  const DiamondInit = await ethers.getContractFactory('FactoryDiamondInit')
  const factoryDiamondInit = await DiamondInit.deploy()
  await factoryDiamondInit.deployed()
  console.log('FactoryDiamondInit - ',factoryDiamondInit.address)

  const FacetNames = [
    'DiamondLoupeFacet',
    'OwnershipFacet',
    'BasicFactoryCreatePairFacet',
    'FactoryUtilityFacet',
    'FactoryPausibleFacet',
    'FactoryAccessControlFacet',
    'FactoryMigratePairFacet',
    'FactoryAdminFacet'
  ]
  const cut = []
  for (let FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName)
    const facet = await Facet.deploy()
    await facet.deployed()

    console.log(`${FacetName} deployed: ${facet.address}`)

    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    })
  }

  const diamondCut = await ethers.getContractAt('IDiamondCut', ardMoneyFactoryDiamond.address)

  let functionCall = factoryDiamondInit.interface.encodeFunctionData('init',[feeSetter.address])
  await (await diamondCut.diamondCut(cut, factoryDiamondInit.address, functionCall)).wait()

  const createPairFacet = await ethers.getContractAt('BasicFactoryCreatePairFacet', ardMoneyFactoryDiamond.address)
  const factoryUtilityFacet = await ethers.getContractAt('FactoryUtilityFacet', ardMoneyFactoryDiamond.address)
  const factoryPausibleFacet = await ethers.getContractAt('FactoryPausibleFacet', ardMoneyFactoryDiamond.address)

  const accessControlFacet = await ethers.getContractAt('FactoryAccessControlFacet', ardMoneyFactoryDiamond.address)
  const migratePairFacet = await ethers.getContractAt('FactoryMigratePairFacet', ardMoneyFactoryDiamond.address)
  const factoryAdminFacet = await ethers.getContractAt('FactoryAdminFacet', ardMoneyFactoryDiamond.address)

  const DummyTokenA = await ethers.getContractFactory("DummyTokenA");
  const token0 = await DummyTokenA.deploy();
  await token0.deployed();

  const DummyTokenB = await ethers.getContractFactory("DummyTokenB");
  const token1 = await DummyTokenB.deploy();
  await token1.deployed();

  let tx = await createPairFacet.createPair(token0.address,token1.address,3,3,pairAdmin.address);
  let receipt = await tx.wait()

  let pair = await factoryUtilityFacet.getPair(token0.address,token1.address)
  await (await migratePairFacet.removePair(pair)).wait()

  console.log(await factoryUtilityFacet.allPairsLength())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  deployDiamond()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })
}
