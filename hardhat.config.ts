import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'
dotenv.config({ path: __dirname + '/.env' })
const config: HardhatUserConfig = {
  solidity: '0.8.26',
  networks: {
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/c57eb9c303154af2b82bc91705e80c22`,
      accounts: [`0x${process.env.PRIVATE_KEY_MAINNET}`],
    },
    amoy: {
      url: `https://rpc-amoy.polygon.technology`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    }
  },
  etherscan: {
    apiKey: process.env.API_KEY
  }
}
