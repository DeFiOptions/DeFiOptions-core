pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../common/utils/MoreAssert.sol";

contract TestPoolYield is Base {

    uint[] yd;
    uint[] dt;

    function testYieldAfterDeposits() public {

        uint vBase = 1e6;
        time.setTimeOffset(0);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 0, "length t0");

        depositInPool(address(bob), 10 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 1, "length t1");
        Assert.equal(yd[0], fractionBase, "yield t1");
        time.setTimeOffset(30 days);
        depositInPool(address(bob), 5 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 2, "length t2");
        Assert.equal(yd[1], fractionBase, "yield t2");

        time.setTimeOffset(90 days);
        depositInPool(address(alice), 2 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 3, "length t3");
        Assert.equal(yd[2], fractionBase, "yield t3");
        
        Assert.equal(dt[0], 30 days, "dt[0]]");
        Assert.equal(dt[1], 60 days, "dt[1]");
        Assert.equal(dt[2], 0, "dt[2]");
    }

    function testYieldAfterSingleProfit() public {

        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 10 * vBase);

        time.setTimeOffset(180 days);
        depositInExchangeToPool(2 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 1, "length t1");
        Assert.equal(yd[0], 1200000000, "yield t1");
        Assert.equal(dt[0], 180 days, "dt t1");

        time.setTimeOffset(365 days);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 1, "length t2");
        Assert.equal(yd[0], 1200000000, "yield t2");
        Assert.equal(dt[0], 365 days, "dt t2");

        time.setTimeOffset(500 days);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 1, "length t3");
        Assert.equal(yd[0], 1200000000, "yield t3");
        Assert.equal(dt[0], 500 days, "dt t3");
    }

    function testYieldAfterMultipleProfits() public {

        cBase = 1e3;
        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 10 * vBase);
        
        time.setTimeOffset(180 days);
        depositInExchangeToPool(1 * vBase);
        depositInPool(address(bob), 5 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 2, "length t1");
        Assert.equal(yd[0], 1100000000, "yield t1");
        Assert.equal(dt[0], 180 days, "dt t1");

        time.setTimeOffset(365 days);
        depositInExchangeToPool(2 * vBase);
        depositInPool(address(bob), 10 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 3, "length t2");
        Assert.equal(yd[1], 1125000000, "yield t2");
        Assert.equal(dt[1], 185 days, "dt t2");

        time.setTimeOffset(500 days);
        depositInExchangeToPool(56 * vBase / 10);
        depositInPool(address(bob), 2 * vBase);
        (yd, dt) = pool.yield();
        Assert.equal(yd.length, 4, "length t3");
        Assert.equal(yd[2], 1200000000, "yield t3");
        Assert.equal(dt[2], 135 days, "dt t3");
    }

    function depositInExchangeToPool(uint value) private {

        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(pool), address(erc20), value);
    }
}