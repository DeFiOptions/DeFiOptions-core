const Deployer = artifacts.require("Deployer");

const TimeProviderMock = artifacts.require("TimeProviderMock");
const EthFeedMock = artifacts.require("EthFeedMock");

const ProtocolSettings = artifacts.require("ProtocolSettings");
const GovToken = artifacts.require("GovToken");

const CreditToken = artifacts.require("CreditToken");
const CreditProvider = artifacts.require("CreditProvider");
const OptionsExchange = artifacts.require("OptionsExchange");

module.exports = async function(deployer) {

  await deployer.deploy(Deployer, "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000");
  await deployer.deploy(TimeProviderMock, Deployer.address);
  await deployer.deploy(EthFeedMock, Deployer.address);
  await deployer.deploy(ProtocolSettings, Deployer.address);
  await deployer.deploy(CreditToken, Deployer.address);
  await deployer.deploy(GovToken, Deployer.address);
  await deployer.deploy(CreditProvider, Deployer.address);
  await deployer.deploy(OptionsExchange, Deployer.address);
};