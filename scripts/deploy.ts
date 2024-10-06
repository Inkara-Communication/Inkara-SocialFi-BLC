import { ethers, hardhatArguments } from 'hardhat'
import * as Config from './config'

async function main() {
  await Config.initConfig()
  const network = hardhatArguments.network ? hardhatArguments.network : 'dev'
  const [deployer] = await ethers.getSigners()
  console.log('Deploying from address:', deployer.address)

  // const GQBToken = await ethers.getContractFactory('GQBToken')
  // const GQBTokenInstance = await GQBToken.deploy()
  // console.log('GQBToken address: ', await GQBTokenInstance.getAddress())
  // Config.setConfig(network + '.GQBToken', await GQBTokenInstance.getAddress())

  // const QBLoginBonus = await ethers.getContractFactory('QBLoginBonus')
  // const QBLoginBonusInstance = await QBLoginBonus.deploy('0x39d4EbdFCd5Bf1D80f483E08a3f132570B1B81A2')
  // console.log('QBLoginBonus address: ', await QBLoginBonusInstance.getAddress())
  // Config.setConfig(network + '.QBLoginBonus', await QBLoginBonusInstance.getAddress())

  // const MetaTransaction = await ethers.getContractFactory('MetaTransaction')
  // const MetaTransactionInstance = await MetaTransaction.deploy()
  // console.log('MetaTransaction address: ', await MetaTransactionInstance.getAddress())
  // Config.setConfig(network + '.MetaTransaction', await MetaTransactionInstance.getAddress())

  const GoldRushGame = await ethers.getContractFactory('GoldRushGame')
  const GoldRushGameInstance = await GoldRushGame.deploy('0x39d4EbdFCd5Bf1D80f483E08a3f132570B1B81A2')
  console.log('GoldRushGame address: ', await GoldRushGameInstance.getAddress())
  Config.setConfig(network + '.GoldRushGame', await GoldRushGameInstance.getAddress())
  

  await Config.updateConfig()
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
