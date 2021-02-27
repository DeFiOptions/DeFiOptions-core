pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestPoolTrading is Base {

    function testBuyOptionsFromPool() public {

        addCode();

        uint cUnit = calcCollateralUnit();

        depositTokens(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(code);
        uint volume = 15 * volumeBase / 10;
        uint total = buyPrice * volume / volumeBase;

        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit, "alice tokens before buying");
        address addr = alice.buyFromPool(code, buyPrice, volume, address(erc20));
        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit - total, "alice tokens after buying");
        
        uint value = 10 * cUnit + total;
        Assert.equal(exchange.balanceOf(address(pool)), value, "pool balance");
        Assert.equal(exchange.balanceOf(address(alice)), 0, "alice balance");
        
        ERC20 tk = ERC20(addr);
        Assert.equal(tk.balanceOf(address(bob)), 0, "bob options");
        Assert.equal(tk.balanceOf(address(alice)), volume, "alice options");
    }

    function testBuyForCheaperPrice() public {

        addCode();

        uint cUnit = calcCollateralUnit();

        depositTokens(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(code);
        uint volume = 15 * volumeBase / 10;
        
        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.buyFromPool.selector,
                abi.encode(code, buyPrice - 1, volume, address(erc20))
            )
        );
        
        Assert.isFalse(success, "buy cheap should fail");
    }

    function testBuyForHigherPrice() public {

        addCode();

        uint cUnit = calcCollateralUnit();

        depositTokens(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        (uint buyPrice,) = pool.queryBuy(code);
        uint volume = 15 * volumeBase / 10;
        uint total = buyPrice * volume / volumeBase;
        
        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.buyFromPool.selector,
                abi.encode(code, buyPrice * 2, volume, address(erc20))
            )
        );
        
        Assert.isTrue(success, "buy for higher price should succeed");
        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit - total, "alice tokens after buying");
    }

    function testSellOptionsToPool() public {

        addCode();

        uint cUnit = calcCollateralUnit();

        depositTokens(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(5 * cUnit);
        uint id = alice.writeOptions(2, CALL, strike, maturity);
        OptionToken tk = OptionToken(exchange.resolveToken(id));

        (uint sellPrice,) = pool.querySell(code);
        uint volume = 2 * volumeBase;
        uint total = sellPrice * volume / volumeBase;

        Assert.equal(tk.balanceOf(address(alice)), volume, "alice options before sell");
        Assert.equal(tk.balanceOf(address(pool)), 0, "pool options before sell");

        alice.sellToPool(code, sellPrice, volume);

        Assert.equal(tk.balanceOf(address(alice)), 0, "alice options after sell");
        Assert.equal(tk.balanceOf(address(pool)), volume, "pool options after sell");
        
        Assert.equal(exchange.balanceOf(address(pool)), 10 * cUnit - total, "pool balance");
        Assert.equal(exchange.balanceOf(address(alice)), 5 * cUnit + total, "alice balance");
    }

    function testSellForCheapPrice() public {

        addCode();

        uint cUnit = calcCollateralUnit();

        depositTokens(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(5 * cUnit);
        alice.writeOptions(2, CALL, strike, maturity);

        (uint sellPrice,) = pool.querySell(code);
        uint volume = 2 * volumeBase;
        uint total = sellPrice * volume / volumeBase;

        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.sellToPool.selector,
                abi.encode(code, sellPrice / 2, volume)
            )
        );

        Assert.isTrue(success, "sell cheap should succeed");
        Assert.equal(exchange.balanceOf(address(alice)), 5 * cUnit + total, "alice balance");
    }

    function testSellForHigherPrice() public {

        addCode();

        uint cUnit = calcCollateralUnit();

        depositTokens(address(bob), 10 * cUnit);
        erc20.issue(address(alice), 5 * cUnit);

        alice.depositInExchange(5 * cUnit);
        alice.writeOptions(2, CALL, strike, maturity);

        (uint sellPrice,) = pool.querySell(code);
        uint volume = 2 * volumeBase;

        (bool success,) = address(alice).call(
            abi.encodePacked(
                alice.sellToPool.selector,
                abi.encode(code, sellPrice + 1, volume)
            )
        );

        Assert.isFalse(success, "sell for higher price should fail");
    }
}