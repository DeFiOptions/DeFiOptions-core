pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestQueryPool is Base {

    function testQueryWithoutFunds() public {

        addSymbol();

        queryBuyAndAssert(applyBuySpread(y[3]), 0, "buy ATM");
        querySellAndAssert(applySellSpread(y[3]), 0, "sell ATM");

        feed.setPrice(525e18);

        queryBuyAndAssert(applyBuySpread(y[3]), 0, "buy OTM");
        querySellAndAssert(applySellSpread(y[3]), 0, "sell OTM");

        feed.setPrice(575e18);

        queryBuyAndAssert(applyBuySpread((y[3] + y[4]) / 2), 0, "buy ITM");
        querySellAndAssert(applySellSpread((y[3] + y[4]) / 2), 0, "sell ITM");
    }

    function testQueryWithFunds() public {

        createTraders();

        uint balance = 50 * calcCollateralUnit();
        uint freeBalance = 80 * balance / 100;
        uint r = fractionBase - reserveRatio;

        depositInPool(address(bob), balance);

        addSymbol();

        time.setFixedTime(1 days);

        uint p0 = applyBuySpread(y[10]);
        queryBuyAndAssert(
            p0,
            freeBalance * volumeBase / (calcCollateralUnit() - (p0 * r / fractionBase)),
            "buy ATM"
        );
        querySellAndAssert(applySellSpread(y[10]), 200 * volumeBase, "sell ATM");

        feed.setPrice(525e18);

        uint p1 = applyBuySpread(y[10]);
        queryBuyAndAssert(
            p1,
            freeBalance * volumeBase / (calcCollateralUnit() - (p1 * r / fractionBase)),
            "buy OTM"
        );
        querySellAndAssert(applySellSpread(y[10]), 200 * volumeBase, "sell OTM");

        feed.setPrice(575e18);

        uint p2 = applyBuySpread((y[10] + y[11]) / 2);
        queryBuyAndAssert(
            p2,
            freeBalance * volumeBase / (calcCollateralUnit() - (p2 * r / fractionBase)),
            "buy ITM"
        );
        querySellAndAssert(applySellSpread((y[10] + y[11]) / 2), 200 * volumeBase, "sell ITM");
    }

    function testQueryHalfway() public {

        createTraders();

        uint balance = 1000 * calcCollateralUnit();
        depositInPool(address(bob), balance);

        addSymbol();

        time.setFixedTime(15 hours);

        feed.setPrice(575e18);

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