pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/finance/CreditProvider.sol";
import "../../../contracts/finance/CreditToken.sol";
import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../common/actors/OptionsTrader.sol";
import "../../common/mock/ERC20Mock.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/TimeProviderMock.sol";

contract Base {
    
    int ethInitialPrice = 550e18;
    uint lowerVol;
    uint upperVol;
    
    uint err = 1; // rounding error
    uint cBase = 1e8; // comparison base
    uint volumeBase = 1e18;
    uint timeBase = 1 hours;
    
    EthFeedMock feed;
    ERC20Mock erc20;
    TimeProviderMock time;

    ProtocolSettings settings;
    CreditProvider creditProvider;
    CreditToken creditToken;
    OptionsExchange exchange;
    
    OptionsTrader bob;
    OptionsTrader alice;
    
    OptionsExchange.OptionType CALL = OptionsExchange.OptionType.CALL;
    OptionsExchange.OptionType PUT = OptionsExchange.OptionType.PUT;
    
    function beforeEachDeploy() public {

        Deployer deployer = Deployer(DeployedAddresses.Deployer());
        deployer.reset();
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        feed = EthFeedMock(deployer.getContractAddress("UnderlyingFeed"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        creditToken = CreditToken(deployer.getContractAddress("CreditToken"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        deployer.deploy();

        bob = new OptionsTrader(address(exchange), address(time), address(feed));
        alice = new OptionsTrader(address(exchange), address(time), address(feed));
        
        uint vol = feed.getDailyVolatility(182 days);
        lowerVol = feed.calcLowerVolatility(vol);
        upperVol = feed.calcUpperVolatility(vol);

        erc20 = new ERC20Mock();
        settings.setOwner(address(this));
        settings.setAllowedToken(address(erc20), 1, 1);
        settings.setUdlFeed(address(feed), 1);

        feed.setPrice(ethInitialPrice);
        time.setTimeOffset(0);
    }

    function depositTokens(address to, uint value) internal {
        
        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(to, address(erc20), value);
    }

    function liquidateAndRedeem(uint id) internal {

        liquidateAndRedeem(exchange.resolveToken(id));
    }

    function liquidateAndRedeem(address token) internal {

        uint maxId = uint(exchange.serial());
        address[] memory owners = exchange.liquidateExpired(1, maxId);
        OptionToken(token).redeem(owners);
    }
}