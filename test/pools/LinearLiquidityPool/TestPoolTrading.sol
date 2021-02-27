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
        uint volume = 15 * volumeBase / 2;
        uint total = buyPrice * volume / volumeBase;

        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit, "alice tokens before buying");
        address addr = alice.buy(code, buyPrice, volume, address(erc20));
        Assert.equal(erc20.balanceOf(address(alice)), 5 * cUnit - total, "alice tokens after buying");
        
        uint value = 10 * cUnit + total;
        Assert.equal(exchange.balanceOf(address(pool)), value, "pool balance");
        Assert.equal(exchange.balanceOf(address(alice)), 0, "alice balance");
        
        ERC20 tk = ERC20(addr);
        Assert.equal(tk.balanceOf(address(bob)), 0, "bob options");
        Assert.equal(tk.balanceOf(address(alice)), volume, "alice options");
    }
}