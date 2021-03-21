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
