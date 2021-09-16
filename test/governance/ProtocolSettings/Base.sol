pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/governance/ProposalsManager.sol";
import "../../../contracts/governance/ProposalWrapper.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../../contracts/governance/GovToken.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../common/actors/ShareHolder.sol";
import "../../common/mock/ERC20Mock.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/TimeProviderMock.sol";
import "../../common/mock/UniswapV2RouterMock.sol";
import "../../common/samples/ChangeInterestRateProposal.sol";

contract Base {
    
    TimeProviderMock time;
    ProtocolSettings settings;
    ProposalsManager manager;
    GovToken govToken;
    
    ShareHolder alpha;
    ShareHolder beta;
    ShareHolder gama;

    ProposalWrapper.Quorum SIMPLE_MAJORITY = ProposalWrapper.Quorum.SIMPLE_MAJORITY;

    function beforeEachDeploy() public {

        Deployer deployer = Deployer(DeployedAddresses.Deployer());
        deployer.reset();
        deployer.deploy(address(this));
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        manager = ProposalsManager(deployer.getContractAddress("ProposalsManager"));
        govToken = GovToken(deployer.getContractAddress("GovToken"));
        
        settings.setCirculatingSupply(1 ether);
        govToken.setChildChainManager(address(this));

        alpha = new ShareHolder(address(govToken), address(manager));
        beta = new ShareHolder(address(govToken), address(manager));
        gama = new ShareHolder(address(govToken), address(manager));
        
        govToken.deposit(address(alpha), abi.encode(1 ether));
        alpha.delegateTo(address(alpha));

        alpha.transfer(address(beta),  99 finney); //  9.9%
        beta.delegateTo(address(beta));

        alpha.transfer(address(gama), 410 finney); // 41.0%
        gama.delegateTo(address(gama));

        time.setTimeOffset(0);
    }

    function createProposal() public returns(ChangeInterestRateProposal p) {

        p = new ChangeInterestRateProposal();
    }
}