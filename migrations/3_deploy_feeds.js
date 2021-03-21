const feed = artifacts.require("ChainlinkFeed");

module.exports = async function(deployer) {

  // await deployer.deploy(
  //   feed, 
  //   "BTC/USD", 
  //   "0x6135b13325bfC4B00278B4abC5e20bbce2D6580e",
  //   "0x3f8171D562c76d49dCdFD99a2F36C040CCb7d7A3",
  //   3 * 60 * 60,
  //   [],
  //   []
  // );

  // await deployer.deploy(
  //   feed, 
  //   "ETH/USD", 
  //   "0x9326BFA02ADD2366b30bacB125260Af641031331",
  //   "0x3f8171D562c76d49dCdFD99a2F36C040CCb7d7A3",
  //   3 * 60 * 60,
  //   [],
  //   []
  // );
};