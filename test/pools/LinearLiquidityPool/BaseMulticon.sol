pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/pools/LinearLiquidityPool.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../common/actors/PoolTrader.sol";
import "../../common/actors/OptionsTrader.sol";
import "../../common/mock/ERC20Mock.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/TimeProviderMock.sol";

contract StablecoinMock is ERC20Mock{
    uint8 private _decimals;
    constructor(uint8 decimals) ERC20Mock() public {
        _decimals=decimals;
    }
    function  decimals() override external view returns (uint8){
        return _decimals;
    }
}

contract Base{
    int ethInitialPrice = 550e18;
    uint strike = 550e18;
    uint maturity = 30 days;
    
    uint err = 1; // rounding error
    uint cBase = 1e6; // comparison base
    uint volumeBase = 1e18;
    uint timeBase = 1 hours;

    uint spread = 5e7; // 5%
    uint reserveRatio = 20e7; // 20%
    uint fractionBase = 1e9;

    EthFeedMock feed;
    //ERC20Mock erc20;
    
    TimeProviderMock time;

    ProtocolSettings settings;
    OptionsExchange exchange;

    LinearLiquidityPool pool;
        
    OptionsExchange.OptionType CALL = OptionsExchange.OptionType.CALL;
    OptionsExchange.OptionType PUT = OptionsExchange.OptionType.PUT;

    uint120[] x;
    uint120[] y;
    string symbol = "ETHM-EC-55e19-2592e3";
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
    

        //erc20 = new ERC20Mock();
        settings.setOwner(address(this));
        //settings.setAllowedToken(address(erc20), 1, 1);
        


        //settings.setDefaultUdlFeed(address(feed));
        settings.setUdlFeed(address(feed), 1);

        //bob = new PoolTrader(address(erc20), address(exchange), address(pool));
        //alice = new PoolTrader(address(erc20), address(exchange), address(pool));

        feed.setPrice(ethInitialPrice);
        time.setFixedTime(0);
    }
    function addSymbol() internal {

        x = [400e18, 450e18, 500e18, 550e18, 600e18, 650e18, 700e18];
        y = [
            30e18,  40e18,  50e18,  50e18, 110e18, 170e18, 230e18,
            25e18,  35e18,  45e18,  45e18, 105e18, 165e18, 225e18
        ];
        
        pool.addSymbol(
            symbol,
            address(feed),
            strike,
            maturity,
            CALL,
            time.getNow(),
            time.getNow() + 1 days,
            x,
            y,
            100 * volumeBase, // buy stock
            200 * volumeBase  // sell stock
        );

        exchange.createSymbol(symbol, address(feed));
    }
    function calcCollateralUnit() internal view returns (uint) {

        return exchange.calcCollateral(
            address(feed), 
            volumeBase,
            CALL,
            strike,
            maturity
        );
    }
    

}