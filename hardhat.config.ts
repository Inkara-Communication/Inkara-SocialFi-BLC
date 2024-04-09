import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'
dotenv.config({ path: __dirname + '/.env' })
const config: HardhatUserConfig = {
  solidity: '0.8.19',
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/6251478dbc1c4a7aa9404e8ab4d6c538`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      gasPrice: 10000000000
    }
  },
  etherscan: {
    apiKey: process.env.API_KEY
  }
}

export default config
