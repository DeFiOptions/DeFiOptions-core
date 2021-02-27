pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/pools/LinearLiquidityPool.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../common/actors/PoolTrader.sol";
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
    
    PoolTrader bob;
    PoolTrader alice;
    
    OptionsExchange.OptionType CALL = OptionsExchange.OptionType.CALL;
    OptionsExchange.OptionType PUT = OptionsExchange.OptionType.PUT;

    uint[] x;
    uint[] y;
    string code = "ETHM-EC-55e9-2592e3";
    
    function beforeEachDeploy() public {

        Deployer deployer = Deployer(DeployedAddresses.Deployer());
        deployer.reset();
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        feed = EthFeedMock(deployer.getContractAddress("UnderlyingFeed"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        pool = LinearLiquidityPool(deployer.getContractAddress("LinearLiquidityPool"));
        deployer.deploy();

        pool.setParameters(
            spread,
            reserveRatio,
            90 days
        );

        erc20 = new ERC20Mock();
        settings.setOwner(address(this));
        settings.setAllowedToken(address(erc20), 1, 1);
        settings.setDefaultUdlFeed(address(feed));
        settings.setUdlFeed(address(feed), 1);

        bob = new PoolTrader(address(erc20), address(pool));
        alice = new PoolTrader(address(erc20), address(pool));

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

    function applyBuySpread(uint v) internal view returns (uint) {
        return (v * (spread + fractionBase)) / fractionBase;
    }

    function applySellSpread(uint v) internal view returns (uint) {
        return (v * (fractionBase - spread)) / fractionBase;
    }

    function addCode() internal {

        x = [400e8, 450e8, 500e8, 550e8, 600e8, 650e8, 700e8];
        y = [
            30e8,  40e8,  50e8,  50e8, 110e8, 170e8, 230e8,
            25e8,  35e8,  45e8,  45e8, 105e8, 165e8, 225e8
        ];
        
        pool.addCode(
            code,
            address(feed),
            550e8, // strike
            30 days, // maturity
            CALL,
            time.getNow(),
            x,
            y,
            100 * volumeBase, // buy stock
            200 * volumeBase  // sell stock
        );
    }

    function calcCollateralUnit() internal view returns (uint) {

        return exchange.calcCollateral(
            address(feed), 
            volumeBase,
            CALL,
            550e8, // strike,
            30 days // maturity
        );
    }
}