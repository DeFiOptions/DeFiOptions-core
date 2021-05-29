pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";
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
    
    function testLiquidationBeforeAllowed() public {
        
        underlying.reset(address(this));
        underlying.issue(address(this), 3 * volumeBase);

        address _tk = writeCovered(3, ethInitialPrice, 10 days);

        OptionToken tk = OptionToken(_tk);

        tk.transfer(address(alice), 2 * volumeBase);

        Assert.equal(1 * volumeBase, tk.balanceOf(address(this)), "writer tk balance");
        Assert.equal(2 * volumeBase, tk.balanceOf(address(alice)), "alice tk balance");
            
        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.liquidateOptions.selector,
                abi.encode(_tk, address(alice))
            )
        );
        
        Assert.isFalse(success, "liquidate should fail");
    }

    function testLiquidationAtMaturityOTM() public {
        
        underlying.reset(address(this));
        underlying.issue(address(this), 2 * volumeBase);
        
        int step = 40e18;

        address _tk = writeCovered(2, ethInitialPrice, 10 days);

        OptionToken tk = OptionToken(_tk);
        
        tk.transfer(address(alice), 2 * volumeBase);

        feed.setPrice(ethInitialPrice - step);
        time.setTimeOffset(10 days);

        uint b0 = underlying.balanceOf(address(this));
        Assert.equal(b0, 0, "underlying before liquidation");

        exchange.liquidateOptions(_tk, address(this));

        uint b1 = underlying.balanceOf(address(this));
        Assert.equal(b1, 2 * volumeBase, "underlying after liquidation");

        Assert.equal(exchange.calcCollateral(address(this)), 0, "writer final collateral");
        Assert.equal(alice.calcCollateral(), 0, "alice final collateral");

        Assert.equal(exchange.calcSurplus(address(this)), 0, "writer final surplus");
        Assert.equal(alice.calcSurplus(), 0, "alice final surplus");
    }

    function testLiquidationAtMaturityITM() public {
        
        underlying.reset(address(this));
        underlying.issue(address(this), 2 * volumeBase);

        settings.setSwapRouterInfo(router, address(erc20));
        settings.setSwapRouterTolerance(105e4, 1e6);
        
        int step = 40e18;

        address _tk = writeCovered(2, ethInitialPrice, 200 days);

        Assert.equal(exchange.calcCollateral(address(this)), 0, "writer initial collateral");

        OptionToken tk = OptionToken(_tk);
        
        tk.transfer(address(alice), 2 * volumeBase);

        feed.setPrice(ethInitialPrice + step);
        time.setTimeOffset(200 days);

        uint b0 = underlying.balanceOf(address(this));
        Assert.equal(b0, 0, "underlying before liquidation");

        exchange.liquidateOptions(_tk, address(this));
        tk.redeem(address(alice));

        uint b1 = underlying.balanceOf(address(this));
        uint exp = 10 ** uint(underlying.decimals());
        uint udl = (2 * volumeBase) - (2 * uint(step) * exp / uint(feed.getPrice()));
        Assert.equal(b1, udl, "underlying after liquidation");

        Assert.equal(exchange.calcCollateral(address(this)), 0, "writer final collateral");
        Assert.equal(alice.calcCollateral(), 0, "alice final collateral");

        Assert.equal(exchange.calcSurplus(address(this)), 0, "writer final surplus");
        Assert.equal(alice.calcSurplus(), uint(2 * step), "alice final surplus");
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