pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestPoolTrading is Base {

    function testBuyOptionsFromPool() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(symbol);
        uint volume = 15 * volumeBase / 10;
        uint total = buyPrice * volume / volumeBase;

        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit, "alice tokens before buying");
        address addr = alice.buyFromPool(symbol, buyPrice, volume);
        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit - total, "alice tokens after buying");
        
        uint value = 10 * cUnit + total;
        Assert.equal(exchange.balanceOf(address(pool)), value, "pool balance");
        Assert.equal(exchange.balanceOf(address(alice)), 0, "alice balance");
        
        OptionToken tk = OptionToken(addr);
        Assert.equal(tk.balanceOf(address(bob)), 0, "bob options");
        Assert.equal(tk.balanceOf(address(alice)), volume, "alice options");
        Assert.equal(tk.writtenVolume(address(pool)), volume, "pool written volume");
    }

    function testBuyForCheaperPrice() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(symbol);
        uint volume = 15 * volumeBase / 10;
        
        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.buyFromPool.selector,
                abi.encode(symbol, buyPrice - 1, volume)
            )
        );
        
        Assert.isFalse(success, "buy cheap should fail");
    }

    function testBuyForHigherPrice() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(symbol);
        uint volume = 15 * volumeBase / 10;
        uint total = buyPrice * volume / volumeBase;
        
        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.buyFromPool.selector,
                abi.encode(symbol, buyPrice * 2, volume)
            )
        );
        
        Assert.isTrue(success, "buy for higher price should succeed");
        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit - total, "alice tokens after buying");
    }

    function testSellOptionsToPool() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(5 * cUnit);
        address _tk = alice.writeOptions(2, CALL, strike, maturity);
        OptionToken tk = OptionToken(_tk);

        (uint sellPrice,) = pool.querySell(symbol);
        uint volume = 2 * volumeBase;
        uint total = sellPrice * volume / volumeBase;

        Assert.equal(tk.balanceOf(address(alice)), volume, "alice options before sell");
        Assert.equal(tk.balanceOf(address(pool)), 0, "pool options before sell");

        alice.sellToPool(symbol, sellPrice, volume);

        Assert.equal(tk.balanceOf(address(alice)), 0, "alice options after sell");
        Assert.equal(tk.balanceOf(address(pool)), volume, "pool options after sell");
        
        Assert.equal(exchange.balanceOf(address(pool)), 10 * cUnit - total, "pool balance");
        Assert.equal(exchange.balanceOf(address(alice)), 5 * cUnit + total, "alice balance");
    }

    function testSellForCheapPrice() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(5 * cUnit);
        alice.writeOptions(2, CALL, strike, maturity);

        (uint sellPrice,) = pool.querySell(symbol);
        uint volume = 2 * volumeBase;
        uint total = sellPrice * volume / volumeBase;

        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.sellToPool.selector,
                abi.encode(symbol, sellPrice / 2, volume)
            )
        );

        Assert.isTrue(success, "sell cheap should succeed");
        Assert.equal(exchange.balanceOf(address(alice)), 5 * cUnit + total, "alice balance");
    }

    function testSellForHigherPrice() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(5 * cUnit);
        alice.writeOptions(2, CALL, strike, maturity);

        (uint sellPrice,) = pool.querySell(symbol);
        uint volume = 2 * volumeBase;

        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.sellToPool.selector,
                abi.encode(symbol, sellPrice + 1, volume)
            )
        );

        Assert.isFalse(success, "sell for higher price should fail");
    }

    function testBuyFromPoolThenSellBack() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();
        uint volume = 15 * volumeBase / 10;

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(symbol);
        address addr = alice.buyFromPool(symbol, buyPrice, volume);
        
        OptionToken tk = OptionToken(addr);
        Assert.equal(tk.totalSupply(), volume, "token initial supply");
        
        (uint sellPrice,) = pool.querySell(symbol);
        alice.sellToPool(symbol, sellPrice, volume);

        uint diff = (buyPrice - sellPrice) * volume / volumeBase;

        Assert.equal(alice.balance(), 5 * cUnit - diff, "alice balance");
        Assert.equal(tk.balanceOf(address(alice)), 0, "alice tokens");
        Assert.equal(tk.balanceOf(address(pool)), 0, "pool tokens");
        Assert.equal(tk.writtenVolume(address(pool)), 0, "pool written volume");
        Assert.equal(tk.totalSupply(), 0, "token final supply");
    }

    function testSellToPoolThenBuyBack() public {

        createTraders();

        addSymbol();

        uint cUnit = calcCollateralUnit();
        uint volume = 2 * volumeBase;

        depositInPool(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(2 * cUnit);
        address _tk = alice.writeOptions(2, CALL, strike, maturity);
        OptionToken tk = OptionToken(_tk);

        (uint sellPrice,) = pool.querySell(symbol);
        alice.sellToPool(symbol, sellPrice, volume);

        (uint buyPrice,) = pool.queryBuy(symbol);
        alice.buyFromPool(symbol, buyPrice, volume);

        uint diff = (buyPrice - sellPrice) * volume / volumeBase;

        Assert.equal(alice.balance(), 5 * cUnit - diff, "alice balance");
        Assert.equal(tk.balanceOf(address(alice)), volume, "alice tokens");
        Assert.equal(tk.balanceOf(address(pool)), 0, "pool tokens");
        Assert.equal(tk.writtenVolume(address(pool)), 0, "pool written volume");
        Assert.equal(tk.writtenVolume(address(alice)), volume, "alice written volume");
        Assert.equal(tk.totalSupply(), volume, "token final supply");
    }
}