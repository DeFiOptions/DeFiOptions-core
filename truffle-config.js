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
      timeoutBlocks: 200
    },
  
    mumbai: {
      provider: function() {
        return new HDWalletProvider(
          process.env.MNENOMIC,
          "https://polygon-mumbai.infura.io/v3/" + process.env.MATIC_RPC_KEY
        )
      },
      network_id: 80001,
      timeoutBlocks: 200
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
      gasPrice: 5000000000 // 5 gewi
    }
  },

  compilers: {
    solc: {
      version: "0.6.0",
      settings: {
        optimizer: {
          enabled: true,
          runs: 500
        }
      }
    }
  },
  
  plugins: [
    'truffle-plugin-verify'
  ],

  api_keys: {
    etherscan: process.env.ETHERSCAN_KEY
  }
};
