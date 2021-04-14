pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./BaseMulticon.sol";

contract TestMulticoinTrading is Base {
    event LogUint(string, uint);//Log event

    StablecoinMock stablecoinA;//Stablecoin A
    StablecoinMock stablecoinB;//Stablecoin B
    StablecoinMock stablecoinC;//Stablecoin C

    uint OptionsPrice;

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

        emit LogUint("0.OptionsPrice is",OptionsPrice);
    }

/*
testBuyWithMultipleCoins
Initialize the LiquidityPool
Trader A deposits the amount of 10*P Stablecoins A in the LiquidityPool
Trader B buys an option from the pool paying the amount of P with Stablecoin B
Trader C buys an option from the pool paying the amount of P with Stablecoin C
Verify that all options were issued correctly and that the liquidity pool balance is 12*P
*/
    function testBuyWithMultipleCoins() public{
        uint decimals_diff=0;
        //Trader A deposits the amount of 100*P Stablecoins A in the LiquidityPool
        PoolTrader userA = new PoolTrader(address(stablecoinA), address(exchange), address(pool),address(feed));  
        uint volumeA = 100;//this volume is base by Options,not decimals
        uint amount =volumeA*OptionsPrice;

        stablecoinA.issue(address(this), amount);
        stablecoinA.approve(address(pool), amount);
        pool.depositTokens(address(userA), address(stablecoinA), amount);

        Assert.equal(pool.balanceOf(address(userA)), amount, "userA stablecoinA after deposit");
        emit LogUint("1.balanceOf(pool) userA deposit",exchange.balanceOf(address(pool)));
        //options volume
        uint volume = 1 * volumeBase;

        //Trader B buys an option from the pool paying the amount of P with Stablecoin B
        PoolTrader userB = new PoolTrader(address(stablecoinB), address(exchange), address(pool),address(feed));
        decimals_diff=1e9;
        stablecoinB.issue(address(userB), volume * OptionsPrice / decimals_diff);

        address addr_B = userB.buyFromPool(symbol, OptionsPrice, volume);
        
        OptionToken tk_B = OptionToken(addr_B);
        Assert.equal(tk_B.balanceOf(address(userB)), volume, "userB options");
        emit LogUint("1.balanceOf(pool) after userB buy",exchange.balanceOf(address(pool)));

        //Trader C buys an option from the pool paying the amount of P with Stablecoin C
        PoolTrader userC = new PoolTrader(address(stablecoinC), address(exchange), address(pool),address(feed));
        decimals_diff=1e12;
        stablecoinC.issue(address(userC), volume * OptionsPrice / decimals_diff);

        address addr_C = userC.buyFromPool(symbol, OptionsPrice, volume);
        OptionToken tk_C = OptionToken(addr_C);
        Assert.equal(tk_C.balanceOf(address(userC)), volume, "userC options");

        emit LogUint("1.balanceOf(pool) after userC buy",exchange.balanceOf(address(pool)));

        //Verify that all options were issued correctly and that the liquidity pool balance is 102*P
        Assert.equal(exchange.balanceOf(address(pool)),(100+2)*OptionsPrice,"get pool balance from exchange");
    }
/*
testBuyWithCombinationOfCoins

Initialize the LiquidityPool
Trader A deposits the amount of 10*P Stablecoins A in the LiquidityPool
Trader B deposits the amount of P/2 Stablecoins B in the OptionsExchange
Trader B deposits the amount of P/2 Stablecoins C in the OptionsExchange
Trader B buys an option from the pool paying with his exchange balance
Verify that the option was issued correctly and that the liquidity pool balance is 11*P
*/
    function testBuyWithCombinationOfCoins() public{
        uint decimals_diff=0;
        uint amount=0;
        uint totalBalance_userB=0;
        //Trader A deposits the amount of 100*P Stablecoins A in the LiquidityPool
        PoolTrader userA = new PoolTrader(address(stablecoinA), address(exchange), address(pool),address(feed));  
        uint volumeA = 10;//this volume is base by Options,not decimals
        amount =volumeA*OptionsPrice;

        stablecoinA.issue(address(this), amount);
        stablecoinA.approve(address(pool), amount);
        pool.depositTokens(address(userA), address(stablecoinA), amount);

        Assert.equal(pool.balanceOf(address(userA)), amount, "userA stablecoinA after deposit");
        emit LogUint("2.balanceOf(pool) userA deposit",exchange.balanceOf(address(pool)));
        
        //Trader B deposits the amount of P/2 Stablecoins B in the OptionsExchange
        PoolTrader userB = new PoolTrader(address(stablecoinB), address(exchange), address(pool),address(feed)); 
        decimals_diff=1e9;//StablecoinB decimals is 9,diff=1e/(18-9)
        amount =OptionsPrice/2/decimals_diff;//OptionsPrice decimals is 18

        stablecoinB.issue(address(this), amount);
        emit LogUint("2.amount(stB) userB issue",amount);

        stablecoinB.approve(address(exchange), amount);
        exchange.depositTokens(address(userB), address(stablecoinB), amount);
        
        emit LogUint("2.balanceOf(ex) userB deposit",exchange.balanceOf(address(userB)));

        totalBalance_userB=amount*decimals_diff;        
        Assert.equal(exchange.balanceOf(address(userB)), totalBalance_userB, "userB stablecoinB after deposit");
        
        //Trader B deposits the amount of P/2 Stablecoins C in the OptionsExchange
        //Continue to use  userB
        decimals_diff=1e12;//StablecoinC decimals is 6,diff=1e/(18-6)
        amount =OptionsPrice/2/decimals_diff;//OptionsPrice decimals is 18

        stablecoinC.issue(address(this), amount);
        emit LogUint("2.amount(stC) userB issue",amount);

        stablecoinC.approve(address(exchange), amount);
        exchange.depositTokens(address(userB), address(stablecoinC), amount);
        
        emit LogUint("2.balanceOf(ex) userB deposit",exchange.balanceOf(address(userB)));
        totalBalance_userB=totalBalance_userB+amount*decimals_diff;
        
        Assert.equal(exchange.balanceOf(address(userB)), totalBalance_userB, "userB stablecoinC after deposit");
        //Trader B buys an option from the pool paying with his exchange balance
        //Continue to use  userB with stablecoinB to buy
        uint volume = 1 * volumeBase;
        decimals_diff=1e9;
        stablecoinB.issue(address(userB), volume * OptionsPrice /decimals_diff);

        address addr = userB.buyFromPool(symbol, OptionsPrice, volume);
        
        OptionToken tk = OptionToken(addr);
        Assert.equal(tk.balanceOf(address(userB)), volume, "userB options");
        emit LogUint("2.balanceOf(pool) after userB buy",exchange.balanceOf(address(pool)));
        //Verify that the option was issued correctly and that the liquidity pool balance is 101*P
        Assert.equal(exchange.balanceOf(address(pool)),(10+1)*OptionsPrice,"get pool balance from exchange");
    }
/*
testSellAndWithdrawCombinationOfCoins

Initialize the LiquidityPool
Trader A deposits the amount of 2*P/3 Stablecoins A in the LiquidityPool
Trader A deposits the amount of 2*P/3 Stablecoins B in the LiquidityPool
Trader B deposits the amount of 5*P Stablecoins C in the OptionsExchange
Trader B writes an option in the OptionsExchange
Trader B sells his option to the LiquidityPool
The option expires OTM (out-of-the-money)
Trader B withdraws all his exchange balance
Verify that Trader B balances is a combination of Stablecoins “A”, “B” and “C” whose value add up to 6*P
*/
    function testSellAndWithdrawCombinationOfCoins() public {
        uint decimals_diff=0;
        uint amount=0;
        uint pool_total=0;
        //Trader A deposits the amount of 2*P/3 Stablecoins A in the LiquidityPool
        PoolTrader userA = new PoolTrader(address(stablecoinA), address(exchange), address(pool),address(feed));  
        amount =2*OptionsPrice/3;

        stablecoinA.issue(address(this), amount);
        stablecoinA.approve(address(pool), amount);
        pool.depositTokens(address(userA), address(stablecoinA), amount);
        pool_total=amount;

        Assert.equal(pool.balanceOf(address(userA)), pool_total, "userA stablecoinA after deposit");
        emit LogUint("3.balanceOf(pool) userA deposit",exchange.balanceOf(address(pool)));

        //Trader A deposits the amount of 2*P/3 Stablecoins B in the LiquidityPool
        //Continue to use  userA
        decimals_diff=1e9;
        amount =2*OptionsPrice/3/decimals_diff;

        stablecoinB.issue(address(this), amount);
        stablecoinB.approve(address(pool), amount);
        pool.depositTokens(address(userA), address(stablecoinB), amount);
        pool_total=pool_total+amount*decimals_diff;

        Assert.equal(pool.balanceOf(address(userA)), pool_total, "userA stablecoinB after deposit");
        emit LogUint("3.balanceOf(pool) userA deposit",exchange.balanceOf(address(pool)));

        //Trader B deposits the amount of 10*P Stablecoins C in the OptionsExchange
        PoolTrader userB = new PoolTrader(address(stablecoinA), address(exchange), address(pool),address(feed));  

        decimals_diff=1e12;
        amount =10*OptionsPrice/decimals_diff;

        stablecoinC.issue(address(this), amount);
        stablecoinC.approve(address(exchange), amount);
        exchange.depositTokens(address(userB), address(stablecoinC), amount);
        
        emit LogUint("3.balanceOf(ex) userB deposit",exchange.balanceOf(address(userB)));
        Assert.equal(exchange.balanceOf(address(userB)), amount*decimals_diff, "userB stablecoinC after deposit");

        //期权的买家又叫持权人(holder)，期权的卖家又叫立权人(writer)。
        //Trader B writes an option in the OptionsExchange
        uint test_strike=550e18;
        uint id = userB.writeOptions(1, CALL, test_strike, 30 days);
        OptionToken tk = OptionToken(exchange.resolveToken(id));
        emit LogUint("3.balanceOf(ex) userB write",exchange.balanceOf(address(userB)));

        //Trader B sells his option to the LiquidityPool
        
        uint volume = 1 * volumeBase;
        (uint sellPrice,) = pool.querySell(symbol);
        userB.sellToPool(symbol, sellPrice, volume);
        emit LogUint("3.balanceOf(ex) userB selltopool",exchange.balanceOf(address(userB)));
        emit LogUint("3.userB surplus before liquidate",userB.calcSurplus());

        //The option expires OTM (out-of-the-money)
        uint step = 40e18;
        feed.setPrice(int(test_strike - step));
        time.setTimeOffset(30 days);
        
        userB.liquidateOptions(id);
        emit LogUint("3.userB surplus after liquidate",userB.calcSurplus());
        //Trader B withdraws all his exchange balance
        emit LogUint("3.balanceOf(ex) userB after liquidate",exchange.balanceOf(address(userB)));
        userB.withdrawTokens(exchange.calcSurplus(address(userB)));
        Assert.equal(exchange.balanceOf(address(userB)), 0, "userB exchange balance is zero after withdraw.");

        //todo:Verify that Trader B balances is a combination of Stablecoins “A”, “B” and “C” whose value add up to (10+1)*P
        Assert.notEqual(stablecoinA.balanceOf(address(userB)),0,'stablecoinA balance not zero');
        Assert.notEqual(stablecoinB.balanceOf(address(userB)),0,'stablecoinA balance not zero');
        Assert.notEqual(stablecoinC.balanceOf(address(userB)),0,'stablecoinA balance not zero');
        uint totalValue=stablecoinA.balanceOf(address(userB))+stablecoinB.balanceOf(address(userB))*1e9+stablecoinC.balanceOf(address(userB))*1e12;

        emit LogUint("3.balanceOf(total) userB",totalValue);
        Assert.equal(OptionsPrice*11, totalValue, "userB total value is 11*op");

    }
    
}