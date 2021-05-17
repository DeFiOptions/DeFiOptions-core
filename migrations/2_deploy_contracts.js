var test = true;

const Deployer = artifacts.require("Deployer");
const BlockTimeProvider = artifacts.require("BlockTimeProvider");
const TimeProviderMock = artifacts.require("TimeProviderMock");
const EthFeedMock = artifacts.require("EthFeedMock");
const ProtocolSettings = artifacts.require("ProtocolSettings");
const GovToken = artifacts.require("GovToken");
const CreditToken = artifacts.require("CreditToken");
const CreditProvider = artifacts.require("CreditProvider");
const OptionTokenFactory = artifacts.require("OptionTokenFactory");
const OptionsExchange = artifacts.require("OptionsExchange");
const LinearLiquidityPool = artifacts.require("LinearLiquidityPool");
const LinearInterpolator = artifacts.require("LinearInterpolator");
const YieldTracker = artifacts.require("YieldTracker");

module.exports = async function(deployer) {

  if (test) {
    await deployer.deploy(Deployer, "0x0000000000000000000000000000000000000000");
    await deployer.deploy(TimeProviderMock);
    await deployer.deploy(EthFeedMock);
  } else {
    await deployer.deploy(Deployer, "0x16ceF4db1a82ce9D46A0B294d6290D47f5f3A669");
    await deployer.deploy(BlockTimeProvider);
  }

  await deployer.deploy(ProtocolSettings);
  await deployer.deploy(CreditToken);
  await deployer.deploy(GovToken);
  await deployer.deploy(CreditProvider);
  await deployer.deploy(OptionTokenFactory);
  await deployer.deploy(OptionsExchange);
  await deployer.deploy(LinearLiquidityPool);
  await deployer.deploy(LinearInterpolator);
  await deployer.deploy(YieldTracker);

  var d = await Deployer.deployed();
  
  if (test) {
    d.setContractAddress("TimeProvider", TimeProviderMock.address);
    d.setContractAddress("UnderlyingFeed", EthFeedMock.address);
  } else {
    d.setContractAddress("TimeProvider", BlockTimeProvider.address);
  }
  
  d.setContractAddress("CreditProvider", CreditProvider.address);
  d.addAlias("CreditIssuer", "CreditProvider");
  d.setContractAddress("CreditToken", CreditToken.address);
  d.setContractAddress("OptionsExchange", OptionsExchange.address);
  d.setContractAddress("OptionTokenFactory", OptionTokenFactory.address);
  d.setContractAddress("GovToken", GovToken.address);
  d.setContractAddress("ProtocolSettings", ProtocolSettings.address);
  d.setContractAddress("LinearLiquidityPool", LinearLiquidityPool.address);
  d.setContractAddress("LinearInterpolator", LinearInterpolator.address);
  d.setContractAddress("YieldTracker", YieldTracker.address);
};