pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../common/utils/MoreAssert.sol";

contract TestPoolApy is Base {

    function testApyAfterDeposits() public {

        uint vBase = 1e6;
        time.setTimeOffset(0);
        Assert.equal(pool.apy(), fractionBase, "apy t0");

        depositInPool(address(bob), 10 * vBase);
        Assert.equal(pool.apy(), fractionBase, "apy t1");

        time.setTimeOffset(30 days);
        depositInPool(address(bob), 5 * vBase);
        Assert.equal(pool.apy(), fractionBase, "apy t2");

        time.setTimeOffset(90 days);
        depositInPool(address(alice), 2 * vBase);
        Assert.equal(pool.apy(), fractionBase, "apy t3");
    }

    function testApyAfterSingleProfit() public {

        cBase = 1e3;
        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 10 * vBase);

        time.setTimeOffset(180 days);
        depositInExchangeToPool(2 * vBase);
        MoreAssert.equal(pool.apy(), 1447311361, cBase, "apy t1");

        time.setTimeOffset(365 days);
        MoreAssert.equal(pool.apy(), 1200000000, cBase, "apy t2");

        time.setTimeOffset(500 days);
        MoreAssert.equal(pool.apy(), 1142358216, cBase, "apy t3");
    }

    function testApyAfterMultipleProfits() public {

        cBase = 1e3;
        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 10 * vBase);
        
        time.setTimeOffset(180 days);
        depositInExchangeToPool(1 * vBase);
        depositInPool(address(bob), 5 * vBase);
        MoreAssert.equal(pool.apy(), 1213207725, cBase, "apy t1");

        time.setTimeOffset(365 days);
        depositInExchangeToPool(2 * vBase);
        depositInPool(address(bob), 10 * vBase);
        MoreAssert.equal(pool.apy(), 1237500000, cBase, "apy t2");

        time.setTimeOffset(500 days);
        depositInExchangeToPool(56 * vBase / 10);
        depositInPool(address(bob), 2 * vBase);
        MoreAssert.equal(pool.apy(), 1382553480, cBase, "apy t3");
    }

    function depositInExchangeToPool(uint value) private {

        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(pool), address(erc20), value);
    }
}