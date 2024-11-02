import { ethers, hardhatArguments } from 'hardhat'
import * as Config from './config'

async function main() {
  await Config.initConfig()
  const network = hardhatArguments.network ? hardhatArguments.network : 'dev'
  const [deployer] = await ethers.getSigners()
  console.log('Deploying from address:', deployer.address)

  // const InkaraCurrency = await ethers.getContractFactory('InkaraCurrency')
  // const InkaraCurrencyInstance = await InkaraCurrency.deploy()
  // console.log('InkaraCurrency address: ', await InkaraCurrencyInstance.getAddress())
  // Config.setConfig(network + '.InkaraCurrency', await InkaraCurrencyInstance.getAddress())

  // const InkaraNFT = await ethers.getContractFactory('InkaraNFT')
  // const InkaraNftInstance = await InkaraNFT.deploy()
  // console.log('InkaraNFT address: ', await InkaraNftInstance.getAddress())
  // Config.setConfig(network + '.InkaraNFT', await InkaraNftInstance.getAddress())

  // const InkaraBadge = await ethers.getContractFactory('InkaraBadge')
  // const InkaraBadgeInstance = await InkaraBadge.deploy()
  // console.log('InkaraBadge address: ', await InkaraBadgeInstance.getAddress())
  // Config.setConfig(network + '.InkaraBadge', await InkaraBadgeInstance.getAddress())

  await Config.updateConfig()
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
