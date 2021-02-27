pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestQueryPool is Base {

    function testQueryWithoutFunds() public {

        addSymbol();

        queryBuyAndAssert(applyBuySpread(y[3]), 0, "buy ATM");
        querySellAndAssert(applySellSpread(y[3]), 200 * volumeBase, "sell ATM");

        feed.setPrice(525e8);

        queryBuyAndAssert(applyBuySpread(y[3]), 0, "buy OTM");
        querySellAndAssert(applySellSpread(y[3]), 200 * volumeBase, "sell OTM");

        feed.setPrice(575e8);

        queryBuyAndAssert(applyBuySpread((y[3] + y[4]) / 2), 0, "buy ITM");
        querySellAndAssert(applySellSpread((y[3] + y[4]) / 2), 200 * volumeBase, "sell ITM");
    }

    function testQueryWithFunds() public {

        uint balance = 50 * calcCollateralUnit();
        uint freeBalance = 80 * balance / 100;
        depositTokens(address(bob), balance);

        addSymbol();

        time.setFixedTime(1 days);

        uint p0 = applyBuySpread(y[10]);
        queryBuyAndAssert(p0, freeBalance * volumeBase / (calcCollateralUnit() - p0), "buy ATM");
        querySellAndAssert(applySellSpread(y[10]), 200 * volumeBase, "sell ATM");

        feed.setPrice(525e8);

        uint p1 = applyBuySpread(y[10]);
        queryBuyAndAssert(p1, freeBalance * volumeBase / (calcCollateralUnit() - p1), "buy OTM");
        querySellAndAssert(applySellSpread(y[10]), 200 * volumeBase, "sell OTM");

        feed.setPrice(575e8);

        uint p2 = applyBuySpread((y[10] + y[11]) / 2);
        queryBuyAndAssert(p2, freeBalance * volumeBase / (calcCollateralUnit() - p2), "buy ITM");
        querySellAndAssert(applySellSpread((y[10] + y[11]) / 2), 200 * volumeBase, "sell ITM");
    }

    function testQueryHalfway() public {

        uint balance = 1000 * calcCollateralUnit();
        depositTokens(address(bob), balance);

        addSymbol();

        time.setFixedTime(15 hours);

        feed.setPrice(575e8);

        uint p0 = (y[3] + y[4]) / 2;
        uint p1 = (y[10] + y[11]) / 2;
        uint p = p0 - (15 * (p0 - p1) / 24);

        queryBuyAndAssert(applyBuySpread(p), 100 * volumeBase, "buy halfway");
        querySellAndAssert(applySellSpread(p), 200 * volumeBase, "sell halfway");
    }

    function queryBuyAndAssert(
        uint expectPrice,
        uint expectedVolume,
        string memory message
    )
        private
    {    
        (uint ps, uint vs) = pool.queryBuy(symbol);
        Assert.equal(ps, expectPrice, message);
        Assert.equal(vs, expectedVolume, message);
    }

    function querySellAndAssert(
        uint expectPrice,
        uint expectedVolume,
        string memory message
    )
        private
    {    
        (uint ps, uint vs) = pool.querySell(symbol);
        Assert.equal(ps, expectPrice, message);
        Assert.equal(vs, expectedVolume, message);
    }
}