pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./BaseMulticon.sol";





contract TestMulticoinTrading is Base {
    event LogUint(string, uint);//Log event

    StablecoinMock stablecoinA;//Stablecoin A
    StablecoinMock stablecoinB;//Stablecoin B
    StablecoinMock stablecoinC;//Stablecoin C

    uint OptionsPrice;

    PoolTrader userA;
    PoolTrader userB;
    PoolTrader userC;    

    function beforeEach() public{
        stablecoinA=new StablecoinMock(18);
        settings.setAllowedToken(address(stablecoinA), 1, 1);
        stablecoinB=new StablecoinMock(9);
        settings.setAllowedToken(address(stablecoinB), 1, 1e9);
        stablecoinC=new StablecoinMock(6);
        settings.setAllowedToken(address(stablecoinC), 1, 1e12);

        addSymbol();

        (uint buyPrice,) = pool.queryBuy(symbol);
        OptionsPrice=buyPrice;

        emit LogUint("OptionsPrice is",OptionsPrice);
    }
    function testBuyWithMultipleCoins() public{
        //Trader A deposits the amount of 10*P Stablecoins A in the LiquidityPool
        userA = new PoolTrader(address(stablecoinA), address(exchange), address(pool),address(feed));  
        uint volumeA = 100;//this volume is base by Options,not decimals
        uint amount =volumeA*OptionsPrice;

        stablecoinA.issue(address(this), amount);
        stablecoinA.approve(address(pool), amount);
        pool.depositTokens(address(userA), address(stablecoinA), amount);

        Assert.equal(stablecoinA.balanceOf(address(userA)), 0, "userA stablecoinA before deposit");

        emit LogUint("balanceOf(pool) userA deposit",exchange.balanceOf(address(pool)));

        //options volume

        uint volume = 1 * volumeBase;

        //Trader B buys an option from the pool paying the amount of P with Stablecoin B
        userB = new PoolTrader(address(stablecoinB), address(exchange), address(pool),address(feed));
        stablecoinB.issue(address(userB), volume * OptionsPrice);

        address addr_B = userB.buyFromPool(symbol, OptionsPrice, volume);
        
        OptionToken tk_B = OptionToken(addr_B);
        Assert.equal(tk_B.balanceOf(address(userB)), volume, "userB options");
        emit LogUint("balanceOf(pool) after userB buy",exchange.balanceOf(address(pool)));

        //Trader C buys an option from the pool paying the amount of P with Stablecoin C
        userC = new PoolTrader(address(stablecoinC), address(exchange), address(pool),address(feed));
        stablecoinC.issue(address(userC), volume * OptionsPrice);

        address addr_C = userC.buyFromPool(symbol, OptionsPrice, volume);
        OptionToken tk_C = OptionToken(addr_C);
        Assert.equal(tk_C.balanceOf(address(userC)), volume, "userC options");

        emit LogUint("balanceOf(pool) after userC buy",exchange.balanceOf(address(pool)));

        //Verify that all options were issued correctly and that the liquidity pool balance is 12*P
        emit LogUint("balanceOf(pool) at endding",exchange.balanceOf(address(pool)));
        emit LogUint("test",(100+2)*OptionsPrice);

        Assert.equal(exchange.balanceOf(address(pool)),(100+2)*OptionsPrice,"get pool balance from exchange");
    }
    
}