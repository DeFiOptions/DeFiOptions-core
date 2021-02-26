pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestQueryPool is Base {

    uint[] x;
    uint[] y;
    string code = "ETHM-EC-55e9-2592e3";

    function testQueryWithoutFunds() public {

        addCode();

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

        uint balance = 50 * calcCollateral();
        uint freeBalance = 80 * balance / 100;
        depositTokens(address(bob), balance);

        addCode();

        time.setFixedTime(1 days);

        uint p0 = applyBuySpread(y[10]);
        queryBuyAndAssert(p0, freeBalance * volumeBase / (calcCollateral() - p0), "buy ATM");
        querySellAndAssert(applySellSpread(y[10]), 200 * volumeBase, "sell ATM");

        feed.setPrice(525e8);

        uint p1 = applyBuySpread(y[10]);
        queryBuyAndAssert(p1, freeBalance * volumeBase / (calcCollateral() - p1), "buy OTM");
        querySellAndAssert(applySellSpread(y[10]), 200 * volumeBase, "sell OTM");

        feed.setPrice(575e8);

        uint p2 = applyBuySpread((y[10] + y[11]) / 2);
        queryBuyAndAssert(p2, freeBalance * volumeBase / (calcCollateral() - p2), "buy ITM");
        querySellAndAssert(applySellSpread((y[10] + y[11]) / 2), 200 * volumeBase, "sell ITM");
    }

    function testQueryHalfway() public {

        uint balance = 1000 * calcCollateral();
        depositTokens(address(bob), balance);

        addCode();

        time.setFixedTime(15 hours);

        feed.setPrice(575e8);

        uint p0 = (y[3] + y[4]) / 2;
        uint p1 = (y[10] + y[11]) / 2;
        uint p = p0 - (15 * (p0 - p1) / 24);

        queryBuyAndAssert(applyBuySpread(p), 100 * volumeBase, "buy halfway");
        querySellAndAssert(applySellSpread(p), 200 * volumeBase, "sell halfway");
    }

    function addCode() private {

        x = [400e8, 450e8, 500e8, 550e8, 600e8, 650e8, 700e8];
        y = [
            30e8,  40e8,  50e8,  50e8, 110e8, 170e8, 230e8,
            25e8,  35e8,  45e8,  45e8, 105e8, 165e8, 225e8
        ];
        
        pool.addCode(
            code,
            address(feed),
            550e8, // strike
            30 days, // maturity
            OptionsExchange.OptionType.CALL,
            time.getNow(),
            x,
            y,
            100 * volumeBase, // buy stock
            200 * volumeBase  // sell stock
        );
    }

    function queryBuyAndAssert(
        uint expectPrice,
        uint expectedVolume,
        string memory message
    )
        private
    {    
        (uint ps, uint vs) = pool.queryBuy(code);
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
        (uint ps, uint vs) = pool.querySell(code);
        Assert.equal(ps, expectPrice, message);
        Assert.equal(vs, expectedVolume, message);
    }

    function calcCollateral() private view returns (uint) {

        return exchange.calcCollateral(
            address(feed), 
            volumeBase,
            OptionsExchange.OptionType.CALL,
            550e8, // strike,
            30 days // maturity
        );
    }
}