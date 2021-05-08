pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../../contracts/governance/GovToken.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../common/actors/ShareHolder.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/TimeProviderMock.sol";
import "../../common/samples/ChangeInterestRateProposal.sol";

contract Base {
    
    TimeProviderMock time;
    ProtocolSettings settings;
    GovToken govToken;
    
    ShareHolder alpha;
    ShareHolder beta;
    ShareHolder gama;

    function beforeEachDeploy() public {

        Deployer deployer = Deployer(DeployedAddresses.Deployer());
        deployer.reset();
        deployer.deploy();
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        govToken = GovToken(deployer.getPayableContractAddress("GovToken"));

        alpha = new ShareHolder();
        beta = new ShareHolder();
        gama = new ShareHolder();
        
        govToken.setInitialSupply(address(alpha), 1 ether);
        
        alpha.setGovToken(address(govToken));
        beta.setGovToken(address(govToken));
        gama.setGovToken(address(govToken));

        alpha.transfer(address(beta),  99 finney); //  9.9%
        alpha.transfer(address(gama), 410 finney); // 41.0%

        time.setTimeOffset(0);
    }

    function createProposal(uint expiration) public returns(ChangeInterestRateProposal p) {

        p = new ChangeInterestRateProposal(
            address(time),
            address(settings),
            address(govToken),
            Proposal.Quorum.SIMPLE_MAJORITY,
            now + expiration
        );
    }
}