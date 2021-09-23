pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestPoolVolumes is Base {

    function testPartialBuyingVolume() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint p1, uint v1) = pool.queryBuy(symbol);
        alice.buyFromPool(symbol, p1, v1 / 2);
        (, uint v2) = pool.queryBuy(symbol);

        Assert.equal(v2, v1 / 2 + err, "volume after buying");
    }

    function testFullBuyingVolume() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint p1, uint v1) = pool.queryBuy(symbol);
        alice.buyFromPool(symbol, p1, v1);
        (, uint v2) = pool.queryBuy(symbol);

        Assert.equal(v2, 0, "volume after buying");
    }

    function testPartialSellingVolume() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 1 * cUnit);
        erc20.issue(address(alice), 10 * cUnit);
        alice.depositInExchange(10 * cUnit);

        (uint p1, uint v1) = pool.querySell(symbol);
        alice.writeOptions(10, CALL, strike, maturity);
        alice.sellToPool(symbol, p1, v1 / 2);
        (, uint v2) = pool.querySell(symbol);

        Assert.equal(v2, v1 / 2 + err, "volume after selling");
    }

    function testFullSellingVolume() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 1 * cUnit);
        erc20.issue(address(alice), 10 * cUnit);
        alice.depositInExchange(10 * cUnit);

        (uint p1, uint v1) = pool.querySell(symbol);
        alice.writeOptions(10, CALL, strike, maturity);
        alice.sellToPool(symbol, p1, v1);
        (, uint v2) = pool.querySell(symbol);

        Assert.equal(v2, 0, "volume after selling");
    }

    function testPartialBuyingThenFullSellingVolume() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint p1, uint v1) = pool.queryBuy(symbol);
        alice.buyFromPool(symbol, p1, v1 / 2);
        (, uint v2) = pool.queryBuy(symbol);

        Assert.equal(v2, v1 / 2 + err, "volume after buying");

        erc20.issue(address(bob), 100 * cUnit);
        bob.depositInExchange(100 * cUnit);

        (uint p3, uint v3) = pool.querySell(symbol);
        bob.writeOptions(100, CALL, strike, maturity);
        bob.sellToPool(symbol, p3, v3);
        (, uint v4) = pool.querySell(symbol);

        Assert.equal(v4, 0, "volume after selling");
    }
}