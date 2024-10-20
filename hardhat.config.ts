import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'
dotenv.config({ path: __dirname + '/.env' })
const config: HardhatUserConfig = {
  solidity: '0.8.26',
  networks: {
    emerald: {
      url: `https://testnet.emerald.oasis.io`,
      chainId: 42261,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    }
  },
  etherscan: {
    apiKey: process.env.API_KEY
  }
}
