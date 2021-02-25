pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";

contract TestQueryPool is Base {

    uint[] x;
    uint[] y;
    string code = "ETHM-EC-55e9-2592e3";

    function testQueryBuyWithoutFunds() public {

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

        (uint pb1, uint vb1) = pool.queryBuy(code);
        Assert.equal(pb1, applyBuySpread(y[3]), "buy price ATM");
        Assert.equal(vb1, 0, "buy volume ATM");

        (uint ps1, uint vs1) = pool.querySell(code);
        Assert.equal(ps1, applySellSpread(y[3]), "sell price ATM");
        Assert.equal(vs1, 200 * volumeBase, "sell volume ATM");
    }
}