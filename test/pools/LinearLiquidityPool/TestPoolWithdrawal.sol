pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../common/utils/MoreAssert.sol";
import "./Base.sol";

contract TestPoolWithdrawal is Base {

    uint[] yd;
    uint[] dt;

    function testDepositThenWithdraw() public {

        createTraders();

        uint vBase = 1e6;
        
        depositInPool(address(bob), 100 * vBase);

        Assert.equal(pool.valueOf(address(bob)), 100 * vBase, "bob initial pool value");
        Assert.equal(exchange.balanceOf(address(bob)), 0, "bob initial exchange balance");
        Assert.equal(exchange.balanceOf(address(pool)), 100 * vBase, "pool initial exchange balance");

        depositInPool(address(alice), 100 * vBase);
        bob.withdrawFromPool();

        Assert.equal(pool.valueOf(address(bob)), 0, "bob final pool value");
        Assert.equal(exchange.balanceOf(address(bob)), 97 * vBase, "bob final exchange balance");
        Assert.equal(exchange.balanceOf(address(pool)), 103 * vBase, "pool final exchange balance");
    }

    function testWithdrawOverYield() public {

        createTraders();

        cBase = 1e3;
        uint vBase = 1e6;
        time.setTimeOffset(0);
        depositInPool(address(bob), 1000 * vBase);

        time.setTimeOffset(180 days);
        depositInExchangeToPool(200 * vBase);
        
        time.setTimeOffset(365 days);
        MoreAssert.equal(pool.yield(365 days), 1200 * vBase, cBase, "initial yield");

        depositInPool(address(alice), 1000 * vBase);
        bob.withdrawFromPool();

        Assert.equal(pool.valueOf(address(bob)), 0, "bob final pool value");
        Assert.equal(exchange.balanceOf(address(bob)), 1164 * vBase, "bob final exchange balance");
        Assert.equal(exchange.balanceOf(address(pool)), 1036 * vBase, "pool final exchange balance");

        MoreAssert.equal(pool.yield(365 days), 12432 * 1e5, cBase, "final yield");
    }

    function depositInExchangeToPool(uint value) private {

        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(pool), address(erc20), value);
    }
}