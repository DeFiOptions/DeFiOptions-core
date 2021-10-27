const HDWalletProvider = require("@truffle/hdwallet-provider");

require('dotenv').config();

module.exports = {

  networks: {
    
    kovan: {
      provider: function() {
        return new HDWalletProvider(
          process.env.MNENOMIC,
          "wss://kovan.infura.io/ws/v3/" + process.env.INFURA_API_KEY
        )
      },
      network_id: 42,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 200,
      gasPrice: 1e9 // 1 gewi
    },
  
    matic: {
      provider: function() {
        return new HDWalletProvider(
          process.env.MNENOMIC,
          "https://polygon-mainnet.infura.io/v3/" + process.env.INFURA_API_KEY
        )
      },
      network_id: 137,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 200,
      gasPrice: 50e9 // 50 gewi
    }
  },

  compilers: {
    solc: {
      version: "0.6.0",
      settings: {
        optimizer: {
          enabled: true,
          runs: 100
        }
      }
    }
  },
  
  plugins: [
    'truffle-plugin-verify',
    'truffle-contract-size'
  ],

  api_keys: {
    etherscan: process.env.ETHERSCAN_KEY
  }
};
