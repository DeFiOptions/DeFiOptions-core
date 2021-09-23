pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../common/utils/MoreAssert.sol";
import "./Base.sol";

contract TestPoolShares is Base {

    address[] addr;

    function testSharesAfterDeposit() public {

        createTraders();

        uint vBase = 1e6;

        depositInPool(address(bob), 10 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 10 * vBase, "bob shares t0");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t0");

        depositInPool(address(bob), 5 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 15 * vBase, "bob shares t1");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t1");

        depositInPool(address(alice), 2 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 15 * vBase, "bob shares t2");
        Assert.equal(pool.balanceOf(address(alice)), 2 * vBase, "alice shares t2");
    }

    function testDepositCapacity() public {

        createTraders();

        pool.setParameters(
            spread,
            reserveRatio,
            withdrawFee,
            1000e18, // 1k capacity
            90 days
        );

        (bool s1,) = address(this).call(
            abi.encodePacked(
                this.depositInPool.selector,
                abi.encode(address(bob), 10e18)
            )
        );
        Assert.isTrue(s1, "desposit whithin capacity");

        (bool s2,) = address(this).call(
            abi.encodePacked(
                this.depositInPool.selector,
                abi.encode(address(bob), 989e18)
            )
        );
        Assert.isTrue(s2, "desposit whithin capacity");

        (bool s3,) = address(this).call(
            abi.encodePacked(
                this.depositInPool.selector,
                abi.encode(address(bob), 2e18)
            )
        );
        Assert.isFalse(s3, "desposit above capacity");
    }

    function testSharesUponProfit() public {

        createTraders();

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

        createTraders();

        uint vBase = calcCollateralUnit();

        depositInPool(address(bob), 10 * vBase);
        
        Assert.equal(pool.balanceOf(address(bob)), 10 * vBase, "bob shares t0");
        Assert.equal(pool.balanceOf(address(alice)), 0, "alice shares t0");

        addSymbol();
        (uint buyPrice,) = pool.queryBuy(symbol);
        erc20.issue(address(alice), buyPrice);
        alice.buyFromPool(symbol, buyPrice, volumeBase);
        feed.setPrice(ethInitialPrice + 500e18); // force expected loss
        Assert.equal(exchange.calcExpectedPayout(address(pool)), -500e18, "expected payout");

        depositInPool(address(alice), 100e18);
        
        uint totalFunds = 10 * vBase + buyPrice - 400e18;
        uint expected = pool.totalSupply() * 100e18 / totalFunds;
        Assert.equal(pool.balanceOf(address(bob)), 10 * vBase, "bob shares t1");
        MoreAssert.equal(pool.balanceOf(address(alice)), expected, cBase, "alice shares t1");
    }

    function testRedeemIndividualAddresses() public {

        uint vBase = 1e6;

        setAddresses();

        depositInPool(addr[0], 10 * vBase);
        depositInPool(addr[1], 10 * vBase);
        depositInPool(addr[2], 10 * vBase);
        depositInPool(addr[3], 10 * vBase);
        depositInPool(addr[4], 10 * vBase);
        depositInPool(addr[5], 10 * vBase);
        depositInPool(addr[6], 10 * vBase);
        depositInPool(addr[7], 10 * vBase);
        depositInPool(addr[8], 10 * vBase);

        depositInExchangeToPool(180 * vBase);
        
        Assert.equal(exchange.balanceOf(address(pool)), 270 * vBase, "pool balance");
        Assert.equal(exchange.balanceOf(addr[4]), 0, "addr[4] balance");
        Assert.equal(exchange.balanceOf(addr[7]), 0, "addr[7] balance");
        Assert.equal(exchange.balanceOf(addr[8]), 0, "addr[8] balance");

        time.setFixedTime(90 days);
        pool.redeem(addr[4]);
        pool.redeem(addr[8]);

        Assert.equal(exchange.balanceOf(address(pool)), 210 * vBase, "pool balance");
        Assert.equal(exchange.balanceOf(addr[4]), 30 * vBase, "addr[4] balance");
        Assert.equal(exchange.balanceOf(addr[7]), 0, "addr[7] balance");
        Assert.equal(exchange.balanceOf(addr[8]), 30 * vBase, "addr[8] balance");
    }

    function testRedeemAllAddressesPool() public {

        uint vBase = 1e6;

        setAddresses();

        depositInPool(addr[0], 10 * vBase);
        depositInPool(addr[1], 10 * vBase);
        depositInPool(addr[2], 10 * vBase);
        depositInPool(addr[3], 10 * vBase);
        depositInPool(addr[4], 10 * vBase);
        depositInPool(addr[5], 10 * vBase);
        depositInPool(addr[6], 10 * vBase);
        depositInPool(addr[7], 10 * vBase);
        depositInPool(addr[8], 10 * vBase);

        depositInExchangeToPool(180 * vBase);
        
        Assert.equal(exchange.balanceOf(address(pool)), 270 * vBase, "pool balance");
        Assert.equal(exchange.balanceOf(addr[0]), 0, "addr[0] balance");
        Assert.equal(exchange.balanceOf(addr[1]), 0, "addr[1] balance");
        Assert.equal(exchange.balanceOf(addr[2]), 0, "addr[2] balance");
        Assert.equal(exchange.balanceOf(addr[3]), 0, "addr[3] balance");
        Assert.equal(exchange.balanceOf(addr[4]), 0, "addr[4] balance");
        Assert.equal(exchange.balanceOf(addr[5]), 0, "addr[5] balance");
        Assert.equal(exchange.balanceOf(addr[6]), 0, "addr[6] balance");
        Assert.equal(exchange.balanceOf(addr[7]), 0, "addr[7] balance");
        Assert.equal(exchange.balanceOf(addr[8]), 0, "addr[8] balance");

        time.setFixedTime(90 days);
        pool.redeem(addr);

        Assert.equal(exchange.balanceOf(address(pool)), 0, "pool balance");
        Assert.equal(exchange.balanceOf(addr[0]), 30 * vBase, "addr[0] balance");
        Assert.equal(exchange.balanceOf(addr[1]), 30 * vBase, "addr[1] balance");
        Assert.equal(exchange.balanceOf(addr[2]), 30 * vBase, "addr[2] balance");
        Assert.equal(exchange.balanceOf(addr[3]), 30 * vBase, "addr[3] balance");
        Assert.equal(exchange.balanceOf(addr[4]), 30 * vBase, "addr[4] balance");
        Assert.equal(exchange.balanceOf(addr[5]), 30 * vBase, "addr[5] balance");
        Assert.equal(exchange.balanceOf(addr[6]), 30 * vBase, "addr[6] balance");
        Assert.equal(exchange.balanceOf(addr[7]), 30 * vBase, "addr[7] balance");
        Assert.equal(exchange.balanceOf(addr[8]), 30 * vBase, "addr[8] balance");
    }

    function depositInExchangeToPool(uint value) private {

        erc20.issue(address(this), value);
        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(pool), address(erc20), value);
    }

    function setAddresses() private returns (address[] memory) {

        addr = [
            address(0x0000000000000000000000000000000000000001),
            address(0x0000000000000000000000000000000000000002),
            address(0x0000000000000000000000000000000000000003),
            address(0x0000000000000000000000000000000000000004),
            address(0x0000000000000000000000000000000000000005),
            address(0x0000000000000000000000000000000000000006),
            address(0x0000000000000000000000000000000000000007),
            address(0x0000000000000000000000000000000000000008),
            address(0x0000000000000000000000000000000000000009)
        ];
    }
}