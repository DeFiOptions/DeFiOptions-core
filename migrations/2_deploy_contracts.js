var test = true;

const Deployer = artifacts.require("Deployer");
const BlockTimeProvider = artifacts.require("BlockTimeProvider");
const TimeProviderMock = artifacts.require("TimeProviderMock");
const ProtocolSettings = artifacts.require("ProtocolSettings");
const GovToken = artifacts.require("GovToken");
const CreditToken = artifacts.require("CreditToken");
const UnderlyingVault = artifacts.require("UnderlyingVault");
const CreditProvider = artifacts.require("CreditProvider");
const OptionTokenFactory = artifacts.require("OptionTokenFactory");
const OptionsExchange = artifacts.require("OptionsExchange");
const LinearInterpolator = artifacts.require("LinearInterpolator");
const YieldTracker = artifacts.require("YieldTracker");
const LinearLiquidityPool = artifacts.require("LinearLiquidityPool");

const Stablecoin = artifacts.require("ERC20Mock");
const UnderlyingToken = artifacts.require("ERC20Mock");
const UnderlyingFeed = artifacts.require("EthFeedMock");
const SwapRouter = artifacts.require("UniswapV2RouterMock");

module.exports = async function(deployer) {

  if (test) {
    await deployer.deploy(Deployer, "0x0000000000000000000000000000000000000000");
    await deployer.deploy(TimeProviderMock);
    await deployer.deploy(UnderlyingToken, 18);
    await deployer.deploy(UnderlyingFeed);
    await deployer.deploy(SwapRouter);
  } else {
    await deployer.deploy(Deployer, "0x16ceF4db1a82ce9D46A0B294d6290D47f5f3A669");
    await deployer.deploy(BlockTimeProvider);
  }

  await deployer.deploy(ProtocolSettings);
  await deployer.deploy(GovToken);
  await deployer.deploy(CreditToken);
  await deployer.deploy(UnderlyingVault);
  await deployer.deploy(CreditProvider);
  await deployer.deploy(OptionTokenFactory);
  await deployer.deploy(OptionsExchange);
  await deployer.deploy(LinearInterpolator);
  await deployer.deploy(YieldTracker);
  await deployer.deploy(LinearLiquidityPool);

  var d = await Deployer.deployed();
  
  if (test) {
    d.setContractAddress("TimeProvider", TimeProviderMock.address);
    await deployer.deploy(Stablecoin, 18);
    d.setContractAddress("StablecoinA", Stablecoin.address, false);
    await deployer.deploy(Stablecoin, 9);
    d.setContractAddress("StablecoinB", Stablecoin.address, false);
    await deployer.deploy(Stablecoin, 6);
    d.setContractAddress("StablecoinC", Stablecoin.address, false);
    d.setContractAddress("UnderlyingToken", UnderlyingToken.address, false);
    d.setContractAddress("UnderlyingFeed", UnderlyingFeed.address);
    d.setContractAddress("SwapRouter", SwapRouter.address);
  } else {
    d.setContractAddress("TimeProvider", BlockTimeProvider.address);
  }
  
  d.setContractAddress("ProtocolSettings", ProtocolSettings.address);
  d.setContractAddress("GovToken", GovToken.address);
  d.setContractAddress("CreditToken", CreditToken.address);
  d.setContractAddress("UnderlyingVault", UnderlyingVault.address);
  d.setContractAddress("CreditProvider", CreditProvider.address);
  d.addAlias("CreditIssuer", "CreditProvider");
  d.setContractAddress("OptionsExchange", OptionsExchange.address);
  d.setContractAddress("OptionTokenFactory", OptionTokenFactory.address);
  d.setContractAddress("LinearInterpolator", LinearInterpolator.address);
  d.setContractAddress("YieldTracker", YieldTracker.address);
  d.setContractAddress("LinearLiquidityPool", LinearLiquidityPool.address);
};