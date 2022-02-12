pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/utils/MoreMath.sol";
import "./Base.sol";

contract TestCoveredOption is Base {
    
    function testWriteCoveredCall() public {

        underlying.reset(address(this));
        underlying.issue(address(this), volumeBase);

        address _tk = writeCovered(1, ethInitialPrice, 10 days);

        OptionToken tk = OptionToken(_tk);
        
        Assert.equal(volumeBase, tk.balanceOf(address(this)), "tk balance");
        Assert.equal(volumeBase, tk.writtenVolume(address(this)), "tk writtenVolume");
        Assert.equal(0, tk.uncoveredVolume(address(this)), "tk uncoveredVolume");
        Assert.equal(0, exchange.calcCollateral(address(this)), "exchange collateral");
    }
    
    function testBurnCoveredCall() public {

        underlying.reset(address(this));
        underlying.issue(address(this), 2 * volumeBase);

        address _tk = writeCovered(2, ethInitialPrice, 10 days);

        OptionToken tk = OptionToken(_tk);
        tk.burn(volumeBase);
        
        Assert.equal(volumeBase, tk.balanceOf(address(this)), "tk balance t0");
        Assert.equal(volumeBase, tk.writtenVolume(address(this)), "tk writtenVolume t0");
        Assert.equal(volumeBase, underlying.balanceOf(address(this)), "underlying balance t0");
        Assert.equal(0, tk.uncoveredVolume(address(this)), "tk uncoveredVolume t0");
        Assert.equal(0, exchange.calcCollateral(address(this)), "exchange collateral t0");

        tk.burn(volumeBase);
        
        Assert.equal(0, tk.balanceOf(address(this)), "tk balance t1");
        Assert.equal(0, tk.writtenVolume(address(this)), "tk writtenVolume t1");
        Assert.equal(2 * volumeBase, underlying.balanceOf(address(this)), "underlying balance t1");
        Assert.equal(0, tk.uncoveredVolume(address(this)), "tk uncoveredVolume t1");
        Assert.equal(0, exchange.calcCollateral(address(this)), "exchange collateral t1");
    }

    function testBurnCollateral() public {
        
        erc20.reset(address(this));

        uint ct20 = MoreMath.sqrtAndMultiply(20, upperVol);
        
        depositTokens(address(this), ct20);

        address _tk1 = exchange.writeOptions(
            address(feed),
            volumeBase,
            PUT,
            uint(ethInitialPrice),
            time.getNow() + 20 days,
            address(this)
        );

        Assert.equal(exchange.calcCollateral(address(this)), ct20, "writer collateral t0");

        underlying.reset(address(this));
        underlying.issue(address(this), 2 * volumeBase);

        address _tk2 = writeCovered(2, ethInitialPrice, 10 days);

        Assert.equal(exchange.calcCollateral(address(this)), ct20, "writer collateral t1");

        OptionToken(_tk1).burn(volumeBase / 2);

        Assert.equal(exchange.calcCollateral(address(this)), ct20 / 2, "writer collateral t2");

        OptionToken(_tk2).burn(volumeBase);

        Assert.equal(OptionToken(_tk1).balanceOf(address(this)), volumeBase / 2, "balanceOf tk1");
        Assert.equal(OptionToken(_tk1).writtenVolume(address(this)), volumeBase / 2, "writtenVolume tk1");
        Assert.equal(OptionToken(_tk2).balanceOf(address(this)), volumeBase, "balanceOf tk2");
        Assert.equal(OptionToken(_tk2).writtenVolume(address(this)), volumeBase, "writtenVolume tk2");
    }

    function testMixedCollateral() public {
        
        erc20.reset(address(this));

        uint ct10 = MoreMath.sqrtAndMultiply(10, upperVol);
        uint ct20 = MoreMath.sqrtAndMultiply(20, upperVol);
        
        depositTokens(address(this), ct20);

        address _tk1 = exchange.writeOptions(
            address(feed),
            volumeBase,
            PUT,
            uint(ethInitialPrice),
            time.getNow() + 20 days,
            address(this)
        );

        Assert.equal(exchange.calcCollateral(address(this)), ct20, "writer collateral t0");

        underlying.reset(address(this));
        underlying.issue(address(this), 2 * volumeBase);

        settings.setSwapRouterInfo(router, address(erc20));
        settings.setSwapRouterTolerance(105e4, 1e6);
        
        int step = 40e18;

        address _tk2 = writeCovered(2, ethInitialPrice, 10 days);

        OptionToken tk = OptionToken(_tk2);
        
        tk.transfer(address(alice), 2 * volumeBase);

        feed.setPrice(ethInitialPrice + step);
        time.setTimeOffset(10 days);

        Assert.equal(exchange.calcCollateral(address(this)), ct10, "writer collateral t1");

        exchange.liquidateOptions(_tk2, address(this));
        tk.redeem(address(alice));

        Assert.equal(exchange.calcCollateral(address(this)), ct10, "writer collateral t2");

        time.setTimeOffset(20 days);

        exchange.liquidateOptions(_tk1, address(this));

        Assert.equal(exchange.calcCollateral(address(this)), 0, "writer collateral t3");
        Assert.equal(exchange.calcSurplus(address(this)), ct20, "writer final surplus");
    }

    function writeCovered(
        uint volume,
        int strike, 
        uint timeToMaturity
    )
        public
        returns (address _tk)
    {
        IERC20(
            UnderlyingFeed(feed).getUnderlyingAddr()
        ).approve(address(exchange), volume * volumeBase);
        
        _tk = exchange.writeCovered(
            address(feed),
            volume * volumeBase,
            uint(strike),
            time.getNow() + timeToMaturity,
            address(this)
        );
    }
}