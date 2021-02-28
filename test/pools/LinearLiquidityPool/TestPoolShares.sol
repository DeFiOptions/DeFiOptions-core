pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../common/utils/MoreAssert.sol";

contract TestPoolShares is Base {

    function testSharesAfterDeposit() public {

        uint vBase = 1e6;

        depositInPool(address(bob), 10 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 10 * vBase, "bob shares t0");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t0");

        depositInPool(address(bob), 5 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 15 * vBase - err, "bob shares t1");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t1");

        depositInPool(address(alice), 2 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 15 * vBase - err, "bob shares t2");
        Assert.equal(pool.balanceOf(address(alice)), 2 * vBase - err, "alice shares t2");
    }

    function testSharesUponProfit() public {

        uint vBase = 1e6;

        depositInExchangeToPool(10 * vBase); // initial pool balance

        depositInPool(address(bob), 10 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 20 * vBase, "bob shares t0");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t0");

        depositInExchangeToPool(10 * vBase); // fake profit

        depositInPool(address(alice), 2 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 20 * vBase, "bob shares t1");
        Assert.equal(pool.balanceOf(address(alice)), 1333333, "alice shares t1");
    }

    function testSharesUponExpectedPayout() public {

        uint vBase = calcCollateralUnit();

        depositInPool(address(bob), 10 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 10 * vBase, "bob shares t0");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t0");

        addSymbol();
        (uint buyPrice,) = pool.queryBuy(symbol);
        erc20.issue(address(alice), buyPrice);
        alice.buyFromPool(symbol, buyPrice, volumeBase);
        feed.setPrice(ethInitialPrice + 500e8); // force expected loss
        Assert.equal(exchange.calcExpectedPayout(address(pool)), -500e8, "expected payout");

        depositInPool(address(alice), 100e8);
        
        uint totalFunds = 10 * vBase + buyPrice - 400e8;
        uint expected = pool.totalSupply() * 100e8 / totalFunds;
        Assert.equal(pool.balanceOf(address(bob)), 10 * vBase, "bob shares t1");
        MoreAssert.equal(pool.balanceOf(address(alice)), expected, cBase, "alice shares t1");
    }

    function depositInExchangeToPool(uint value) private {

        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(pool), address(erc20), value);
    }
}