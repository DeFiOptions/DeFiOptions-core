pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/pools/LinearLiquidityPool.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../common/actors/OptionsTrader.sol";
import "../../common/mock/ERC20Mock.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/TimeProviderMock.sol";

contract Base {
    
    int ethInitialPrice = 550e8;
    
    uint err = 1; // rounding error
    uint cBase = 1e8; // comparison base
    uint volumeBase = 1e9;
    uint timeBase = 1 hours;

    uint spread = 5e4; // 5%
    uint reserveRatio = 20e4; // 20%
    uint fractionBase = 1e6;

    EthFeedMock feed;
    ERC20Mock erc20;
    TimeProviderMock time;

    ProtocolSettings settings;
    OptionsExchange exchange;

    LinearLiquidityPool pool;
    
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
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        pool = LinearLiquidityPool(deployer.getContractAddress("LinearLiquidityPool"));
        deployer.deploy();

        bob = new OptionsTrader(address(exchange), address(time));
        alice = new OptionsTrader(address(exchange), address(time));

        pool.setParameters(
            spread,
            reserveRatio,
            90 days
        );

        erc20 = new ERC20Mock();
        settings.setOwner(address(this));
        settings.setAllowedToken(address(erc20), 1, 1);
        settings.setDefaultUdlFeed(address(feed));

        feed.setPrice(ethInitialPrice);
        time.setFixedTime(0);
    }

    function depositTokens(address to, uint value) internal {
        
        erc20.issue(address(this), value);
        erc20.approve(address(pool), value);
        pool.depositTokens(to, address(erc20), value);
    }

    function destroyOptionToken(uint id) internal {

        OptionToken(exchange.resolveToken(id)).destroy();
    }

    function destroyOptionToken(address token) internal {

        OptionToken(token).destroy();
    }

    function applyBuySpread(uint x) internal view returns (uint) {
        return (x * (spread + fractionBase)) / fractionBase;
    }

    function applySellSpread(uint x) internal view returns (uint) {
        return (x * (fractionBase - spread)) / fractionBase;
    }
}