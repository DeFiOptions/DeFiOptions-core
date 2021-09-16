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
import "../../common/mock/UniswapV2RouterMock.sol";

contract Base {
    
    int ethInitialPrice = 550e18;
    uint lowerVol;
    uint upperVol;
    
    uint err = 1; // rounding error
    uint cBase = 1e8; // comparison base
    uint volumeBase = 1e18;
    uint timeBase = 1 hours;

    address[] traders;
    address router;
    
    EthFeedMock feed;
    ERC20Mock erc20;
    ERC20Mock underlying;
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
        deployer.deploy(address(this));
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        feed = EthFeedMock(deployer.getContractAddress("UnderlyingFeed"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        creditToken = CreditToken(deployer.getContractAddress("CreditToken"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        erc20 = ERC20Mock(deployer.getContractAddress("StablecoinA"));
        router = deployer.getContractAddress("SwapRouter");

        erc20.reset();

        settings.setAllowedToken(address(erc20), 1, 1);
        settings.setUdlFeed(address(feed), 1);

        underlying = ERC20Mock(feed.getUnderlyingAddr());
        underlying.reset();

        bob = createTrader();
        alice = createTrader();
        
        uint vol = feed.getDailyVolatility(182 days);
        lowerVol = feed.calcLowerVolatility(vol);
        upperVol = feed.calcUpperVolatility(vol);

        feed.setPrice(ethInitialPrice);
        time.setTimeOffset(0);
    }

    function createTrader() internal returns (OptionsTrader) {

        OptionsTrader td = new OptionsTrader(address(exchange), address(time), address(feed));
        traders.push(address(td));
        return td;
    }

    function depositTokens(address to, uint value) internal {
        
        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(to, address(erc20), value);
    }

    function getBookLength() internal view returns (uint total) {

        total = 0;
        for (uint i = 0; i < traders.length; i++) {
            (,,uint[] memory holding,,) = exchange.getBook(traders[i]);
            total += holding.length;
        }
    }

    function liquidateAndRedeem(address _tk) internal {

        exchange.liquidateExpired(_tk, traders);
        OptionToken(_tk).redeem(traders);
    }
}