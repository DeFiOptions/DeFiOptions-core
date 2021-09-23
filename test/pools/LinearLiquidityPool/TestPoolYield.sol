pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../common/utils/MoreAssert.sol";
import "./Base.sol";

contract TestPoolYield is Base {

    uint[] yd;
    uint[] dt;

    function testYieldAfterDeposits() public {

        createTraders();

        uint vBase = 1e6;
        time.setTimeOffset(0);
        Assert.equal(pool.yield(365 days), fractionBase, "yield t0");

        depositInPool(address(bob), 10 * vBase);
        Assert.equal(pool.yield(365 days), fractionBase, "yield t1");

        time.setTimeOffset(30 days);
        depositInPool(address(bob), 5 * vBase);
        Assert.equal(pool.yield(365 days), fractionBase, "yield t2");

        time.setTimeOffset(90 days);
        depositInPool(address(alice), 2 * vBase);
        Assert.equal(pool.yield(365 days), fractionBase, "yield t3");
    }

    function testYieldAfterSingleProfit() public {

        createTraders();

        cBase = 1e3;
        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 10 * vBase);

        time.setTimeOffset(180 days);
        depositInExchangeToPool(2 * vBase);
        MoreAssert.equal(pool.yield(365 days), 1200000000, cBase, "yield t1");

        time.setTimeOffset(365 days);
        MoreAssert.equal(pool.yield(365 days), 1200000000, cBase, "yield t2");

        time.setTimeOffset(500 days);
        MoreAssert.equal(pool.yield(365 days), 1142358216, cBase, "yield t3");
    }

    function testYieldAfterMultipleProfits() public {

        createTraders();

        cBase = 1e3;
        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 10 * vBase);
        
        time.setTimeOffset(180 days);
        depositInExchangeToPool(1 * vBase);
        depositInPool(address(bob), 5 * vBase);
        MoreAssert.equal(pool.yield(365 days), 1100000000, cBase, "yield t1");

        time.setTimeOffset(365 days);
        depositInExchangeToPool(2 * vBase);
        depositInPool(address(bob), 10 * vBase);
        MoreAssert.equal(pool.yield(365 days), 1237500000, cBase, "yield t2");

        time.setTimeOffset(500 days);
        depositInExchangeToPool(56 * vBase / 10);
        depositInPool(address(bob), 2 * vBase);
        MoreAssert.equal(pool.yield(500 days), 1485000000, cBase, "yield t3");
        MoreAssert.equal(pool.yield(365 days), 1382553480, 5e2, "yield t3");
    }

    function depositInExchangeToPool(uint value) private {

        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(pool), address(erc20), value);
    }
}