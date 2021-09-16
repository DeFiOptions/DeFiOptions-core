pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/finance/CreditProvider.sol";
import "../../../contracts/finance/CreditToken.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../common/actors/CreditHolder.sol";
import "../../common/mock/ERC20Mock.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/TimeProviderMock.sol";
import "../../common/mock/UniswapV2RouterMock.sol";

contract Base {
    
    TimeProviderMock time;
    ProtocolSettings settings;
    CreditProvider creditProvider;
    CreditToken creditToken;
    ERC20Mock erc20;
    
    CreditHolder issuer;
    CreditHolder alpha;
    CreditHolder beta;
    
    uint cBase = 1e8; // comparison base
    uint timeBase = 1 hours;

    function beforeEachDeploy() public {

        Deployer deployer = Deployer(DeployedAddresses.Deployer());
        deployer.reset();
        if (!deployer.hasKey("CreditIssuer")) {
            deployer.setContractAddress("CreditIssuer", address(new CreditHolder()));
        }
        deployer.deploy(address(this));
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        creditToken = CreditToken(deployer.getContractAddress("CreditToken"));
        erc20 = ERC20Mock(deployer.getContractAddress("StablecoinA"));
        
        erc20.reset();

        settings.setAllowedToken(address(erc20), 1, 1);
        
        issuer = CreditHolder(deployer.getContractAddress("CreditIssuer"));
        alpha = new CreditHolder();
        beta = new CreditHolder();

        issuer.setCreditToken(address(creditToken));
        alpha.setCreditToken(address(creditToken));
        beta.setCreditToken(address(creditToken));

        time.setTimeOffset(0);
    }

    function addErc20Stock(uint value) internal {
        
        erc20.issue(address(this), value);
        erc20.approve(address(creditProvider), value);
        creditProvider.depositTokens(address(this), address(erc20), value);
    }
}