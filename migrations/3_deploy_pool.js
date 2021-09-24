
const Deployer = artifacts.require("Deployer");
const LinearInterpolator = artifacts.require("LinearInterpolator");
const YieldTracker = artifacts.require("YieldTracker");
const LinearLiquidityPool = artifacts.require("LinearLiquidityPool");

module.exports = async function(deployer) {
  
  await deployer.deploy(LinearInterpolator);
  await deployer.deploy(YieldTracker);
  await deployer.deploy(LinearLiquidityPool);

  var d = await Deployer.deployed();
  
  d.setContractAddress("LinearInterpolator", LinearInterpolator.address);
  d.setContractAddress("YieldTracker", YieldTracker.address);
  d.setContractAddress("LinearLiquidityPool", LinearLiquidityPool.address);
};