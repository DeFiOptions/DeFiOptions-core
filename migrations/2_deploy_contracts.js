var test = true;

const Deployer = artifacts.require("Deployer");
const BlockTimeProvider = artifacts.require("BlockTimeProvider");
const TimeProviderMock = artifacts.require("TimeProviderMock");
const ProtocolSettings = artifacts.require("ProtocolSettings");
const ProposalsManager = artifacts.require("ProposalsManager");
const GovToken = artifacts.require("GovToken");
const CreditToken = artifacts.require("CreditToken");
const UnderlyingVault = artifacts.require("UnderlyingVault");
const CreditProvider = artifacts.require("CreditProvider");
const OptionTokenFactory = artifacts.require("OptionTokenFactory");
const OptionsExchange = artifacts.require("OptionsExchange");

const Stablecoin = artifacts.require("ERC20Mock");
const UnderlyingToken = artifacts.require("ERC20Mock");
const UnderlyingFeed = artifacts.require("EthFeedMock");
const SwapRouter = artifacts.require("UniswapV2RouterMock");

module.exports = async function(deployer) {

  if (test) {
    await deployer.deploy(Deployer, "0x0000000000000000000000000000000000000000");
    await deployer.deploy(TimeProviderMock);
    await deployer.deploy(GovToken, "0x0000000000000000000000000000000000000000");
    await deployer.deploy(UnderlyingToken, 18);
    await deployer.deploy(UnderlyingFeed);
    await deployer.deploy(SwapRouter);
    await deployer.deploy(ProtocolSettings, true);
  } else {
    await deployer.deploy(Deployer, "0x16ceF4db1a82ce9D46A0B294d6290D47f5f3A669");
    await deployer.deploy(BlockTimeProvider);
    await deployer.deploy(GovToken, "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa");
    await deployer.deploy(ProtocolSettings, false);
  }

  await deployer.deploy(ProposalsManager);
  await deployer.deploy(CreditToken);
  await deployer.deploy(UnderlyingVault);
  await deployer.deploy(CreditProvider);
  await deployer.deploy(OptionTokenFactory);
  await deployer.deploy(OptionsExchange);

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
  d.setContractAddress("ProposalsManager", ProposalsManager.address);
  d.setContractAddress("GovToken", GovToken.address);
  d.setContractAddress("CreditToken", CreditToken.address);
  d.setContractAddress("UnderlyingVault", UnderlyingVault.address);
  d.setContractAddress("CreditProvider", CreditProvider.address);
  d.addAlias("CreditIssuer", "CreditProvider");
  d.setContractAddress("OptionsExchange", OptionsExchange.address);
  d.setContractAddress("OptionTokenFactory", OptionTokenFactory.address);
};