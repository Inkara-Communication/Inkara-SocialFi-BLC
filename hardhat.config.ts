import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'
dotenv.config({ path: __dirname + '/.env' })
const config: HardhatUserConfig = {
  solidity: '0.8.19',
  networks: {
    amoy: {
      url: `https://rpc-amoy.polygon.technology`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    }
  },
  etherscan: {
    apiKey: process.env.API_KEY
  }
}

export default config
