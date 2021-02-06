
module.exports = {

  networks: {

  },

  mocha: {
    // timeout: 100000
  },

  compilers: {
    solc: {
      version: "0.6.0",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};