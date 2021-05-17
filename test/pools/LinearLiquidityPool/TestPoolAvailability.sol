pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestPoolAvailability is Base {

    function testSymbolAvailabilityWithoutRange() public {

        addSymbol();

        Assert.isTrue(pool.isAvailable(symbol, BUY), "buy 0");
        Assert.isTrue(pool.isAvailable(symbol, SELL), "sell 0");

        feed.setPrice(4000e18);

        Assert.isTrue(pool.isAvailable(symbol, BUY), "buy 1");
        Assert.isTrue(pool.isAvailable(symbol, SELL), "sell 1");

        Assert.equal(pool.listSymbols(NONE), symbol, "listSymbols");
    }

    function testSymbolAvailabilityWithRanges() public {

        addSymbol();

        pool.setRange(symbol, BUY, 530e18, 600e18);
        pool.setRange(symbol, SELL, 450e18, 550e18);

        Assert.isTrue(pool.isAvailable(symbol, BUY), "buy 0");
        Assert.isTrue(pool.isAvailable(symbol, SELL), "sell 0");

        feed.setPrice(400e18);

        Assert.isFalse(pool.isAvailable(symbol, BUY), "buy 1");
        Assert.isFalse(pool.isAvailable(symbol, SELL), "sell 1");

        feed.setPrice(450e18);

        Assert.isFalse(pool.isAvailable(symbol, BUY), "buy 2");
        Assert.isTrue(pool.isAvailable(symbol, SELL), "sell 2");

        feed.setPrice(525e18);

        Assert.isFalse(pool.isAvailable(symbol, BUY), "buy 3");
        Assert.isTrue(pool.isAvailable(symbol, SELL), "sell 3");

        feed.setPrice(580e18);

        Assert.isTrue(pool.isAvailable(symbol, BUY), "buy 4");
        Assert.isFalse(pool.isAvailable(symbol, SELL), "sell 4");

        feed.setPrice(601e18);

        Assert.isFalse(pool.isAvailable(symbol, BUY), "buy 5");
        Assert.isFalse(pool.isAvailable(symbol, SELL), "sell 5");

        Assert.equal(pool.listSymbols(NONE), symbol, "listSymbols");
    }

    function testUndeployedSymbolAvailability() public {

        string memory putSymbol = "ETHM-EP-55e19-2592e3";

        pool.addSymbol(
            address(feed),
            strike,
            maturity,
            PUT,
            time.getNow(),
            time.getNow() + 1 days,
            x,
            y,
            100 * volumeBase, // buy stock
            200 * volumeBase  // sell stock
        );

        Assert.isTrue(pool.isAvailable(putSymbol, NONE), "undeployed symbol");
    }

    function testUndeployedSymbolBuyAvailability() public {

        string memory putSymbol = "ETHM-EP-55e19-2592e3";

        pool.addSymbol(
            address(feed),
            strike,
            maturity,
            PUT,
            time.getNow(),
            time.getNow() + 1 days,
            x,
            y,
            100 * volumeBase, // buy stock
            200 * volumeBase  // sell stock
        );
        
        (bool success,) = address(pool).call(
            abi.encodePacked(
                pool.isAvailable.selector,
                abi.encode(putSymbol, BUY)
            )
        );
        
        Assert.isFalse(success, "isAvailable BUY should fail");
    }

    function testUndeployedSymbolSellAvailability() public {

        string memory putSymbol = "ETHM-EP-55e19-2592e3";

        pool.addSymbol(
            address(feed),
            strike,
            maturity,
            PUT,
            time.getNow(),
            time.getNow() + 1 days,
            x,
            y,
            100 * volumeBase, // buy stock
            200 * volumeBase  // sell stock
        );
        
        (bool success,) = address(pool).call(
            abi.encodePacked(
                pool.isAvailable.selector,
                abi.encode(putSymbol, SELL)
            )
        );
        
        Assert.isFalse(success, "isAvailable SELL should fail");
    }
}