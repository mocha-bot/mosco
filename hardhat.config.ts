import '@nomicfoundation/hardhat-toolbox';
import { HardhatUserConfig } from 'hardhat/config';

require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: '0.8.27',
  networks: {
    hardhat: {},
    sepolia: {
      url: process.env.SEPOLIA_NETWORK_URL || '',
      accounts: [process.env.PRIVATE_KEY || ''],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || '',
    },
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
