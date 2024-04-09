import { ethers, hardhatArguments } from 'hardhat'
import * as Config from './config'

async function main() {
  await Config.initConfig()
  const network = hardhatArguments.network ? hardhatArguments.network : 'dev'
  const [deployer] = await ethers.getSigners()
  console.log('Deploying from address:', deployer.address)

  const Registry = await ethers.getContractFactory('Registry')
  const RegistryInstance = await Registry.deploy()
  console.log('Registry address: ', await RegistryInstance.getAddress())
  Config.setConfig(network + '.Registry', await RegistryInstance.getAddress())

  const Marketplace = await ethers.getContractFactory('Marketplace')
  const MarketplaceInstance = await Marketplace.deploy(
    RegistryInstance.getAddress()
  )
  console.log('Marketplace address: ', await MarketplaceInstance.getAddress())
  Config.setConfig(
    network + '.Marketplace',
    await MarketplaceInstance.getAddress()
  )

  const Auction = await ethers.getContractFactory('Auction')
  const AuctionInstance = await Auction.deploy(RegistryInstance.getAddress())
  console.log('Auction address: ', await AuctionInstance.getAddress())
  Config.setConfig(network + '.Auction', await AuctionInstance.getAddress())

  const CreatureAccessory = await ethers.getContractFactory('CreatureAccessory')
  const CreatureAccessoryInstance = await CreatureAccessory.deploy(
    MarketplaceInstance.getAddress(),
    AuctionInstance.getAddress()
  )
  console.log(
    'CreatureAccessory address: ',
    await CreatureAccessoryInstance.getAddress()
  )
  Config.setConfig(
    network + '.CreatureAccessory',
    await CreatureAccessoryInstance.getAddress()
  )

  const Creature = await ethers.getContractFactory('Creature')
  const CreatueInstance = await Creature.deploy(
    MarketplaceInstance.getAddress(),
    AuctionInstance.getAddress()
  )
  console.log('Creature address: ', await CreatueInstance.getAddress())
  Config.setConfig(network + '.Creature', await CreatueInstance.getAddress())

  const MezasMockCurrency = await ethers.getContractFactory('MezasMockCurrency')
  const MezasMockCurrencyInstance = await MezasMockCurrency.deploy()
  console.log(
    'MezasMockCurrency address: ',
    await MezasMockCurrencyInstance.getAddress()
  )
  Config.setConfig(
    network + '.MezasMockCurrency',
    await MezasMockCurrencyInstance.getAddress()
  )

  await Config.updateConfig()
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
