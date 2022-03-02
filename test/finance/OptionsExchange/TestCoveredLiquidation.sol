pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/utils/MoreMath.sol";
import "./Base.sol";

contract TestCoveredLiquidation is Base {
    
    function testLiquidationBeforeAllowed() public {
        
        underlying.reset(address(this));
        underlying.issue(address(this), 3 * underlyingBase);

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
        underlying.issue(address(this), 2 * underlyingBase);
        
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
        Assert.equal(b1, 2 * underlyingBase, "underlying after liquidation");

        Assert.equal(exchange.calcCollateral(address(this)), 0, "writer final collateral");
        Assert.equal(alice.calcCollateral(), 0, "alice final collateral");

        Assert.equal(exchange.calcSurplus(address(this)), 0, "writer final surplus");
        Assert.equal(alice.calcSurplus(), 0, "alice final surplus");
    }

    function testLiquidateMultipleITM() public {
        
        underlying.reset(address(this));
        underlying.issue(address(this), 4 * underlyingBase);

        settings.setSwapRouterInfo(router, address(erc20));
        settings.setSwapRouterTolerance(105e4, 1e6);
        
        int step = 40e18;

        address _tk100 = writeCovered(2, ethInitialPrice, 100 days);
        address _tk200 = writeCovered(2, ethInitialPrice, 200 days);

        OptionToken tk100 = OptionToken(_tk100);
        OptionToken tk200 = OptionToken(_tk200);
        
        tk100.transfer(address(alice), 2 * volumeBase);
        tk200.transfer(address(alice), 2 * volumeBase);

        feed.setPrice(ethInitialPrice + step);

        time.setTimeOffset(100 days);
        exchange.liquidateOptions(_tk100, address(this));
        
        time.setTimeOffset(200 days);
        exchange.liquidateOptions(_tk200, address(this));
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