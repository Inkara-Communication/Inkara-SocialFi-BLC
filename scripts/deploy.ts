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
  // const InkaraNftInstance = await InkaraNFT.deploy('0x45e6Ba371cDd3038931FEBBE13f80D416e9D8CD8')
  // console.log('InkaraNFT address: ', await InkaraNftInstance.getAddress())
  // Config.setConfig(network + '.InkaraNFT', await InkaraNftInstance.getAddress())

  // const InkaraReward = await ethers.getContractFactory('InkaraReward')
  // const InkaraRewardInstance = await InkaraReward.deploy('0x45e6Ba371cDd3038931FEBBE13f80D416e9D8CD8')
  // console.log('InkaraReward address: ', await InkaraRewardInstance.getAddress())
  // Config.setConfig(network + '.InkaraReward', await InkaraRewardInstance.getAddress())

  await Config.updateConfig()
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
