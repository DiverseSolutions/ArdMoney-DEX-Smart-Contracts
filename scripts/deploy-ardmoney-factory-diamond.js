const { getSelectors, FacetCutAction } = require('../diamond-helpers')

async function deployDiamond () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]
  const feeSetter = accounts[1]

  // deploy DiamondCutFacet
  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
  const diamondCutFacet = await DiamondCutFacet.deploy()
  await diamondCutFacet.deployed()
  console.log('DiamondCutFacet deployed:', diamondCutFacet.address)

  const ArdMoneyFactoryDiamond = await ethers.getContractFactory("ArdMoneyFactoryDiamond");
  const ardMoneyFactoryDiamond = await ArdMoneyFactoryDiamond.deploy(contractOwner.address,diamondCutFacet.address,feeSetter.address);
  await ardMoneyFactoryDiamond.deployed();
  console.log('ArdMoneyFactoryDiamond deployed:', ardMoneyFactoryDiamond.address)

  const DiamondInit = await ethers.getContractFactory('DiamondInit')
  const diamondInit = await DiamondInit.deploy()
  await diamondInit.deployed()
  console.log('DiamondInit deployed:', diamondInit.address)

  // deploy facets
  console.log('')
  console.log('Deploying facets')
  const FacetNames = [
    'DiamondLoupeFacet',
    'OwnershipFacet',
    'FactoryPairFacet'
  ]
  const cut = []
  for (const FacetName of FacetNames) {
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

  // upgrade diamond with facets
  console.log('')
  console.log('Diamond Cut:', cut)
  const diamondCut = await ethers.getContractAt('IDiamondCut', ardMoneyFactoryDiamond.address)

  let tx,receipt
  
  // call to init function
  let functionCall = diamondInit.interface.encodeFunctionData('init')

  // Update
  tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall)
  console.log('Diamond cut tx: ', tx.hash)
  receipt = await tx.wait()

  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`)
  }

  console.log('Completed diamond cut')
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
