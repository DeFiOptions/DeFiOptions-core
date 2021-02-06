pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";


contract TestOptionLiquidation is Base {
    
    function testLiquidationBeforeAllowed() public {

        uint mu = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), mu);
        uint id = bob.writeOption(CALL, ethInitialPrice, 10 days);

        bob.transferOptions(address(alice), id, 1);
            
        (bool success,) = address(bob).call(
            abi.encodePacked(
                bob.liquidateOptions.selector,
                abi.encode(id)
            )
        );
        
        Assert.isFalse(success, 'liquidate should fail');
    }

    function testPartialLiquidationWhenIssuerLacksCollateral() public {
        
        int step = 40e8;

        uint mu = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), mu);
        uint id = bob.writeOption(CALL, ethInitialPrice, 10 days);

        bob.transferOptions(address(alice), id, 1);

        feed.setPrice(ethInitialPrice + step);

        Assert.equal(bob.calcCollateral(), mu + uint(step), 'bob collateral before liquidation');

        exchange.liquidateOptions(id);

        MoreAssert.equal(bob.calcCollateral(), bob.balance(), cBase, 'bob final collateral');
        Assert.equal(alice.calcCollateral(), 0, 'alice final collateral');

        Assert.equal(bob.calcSurplus(), 0, 'bob final surplus');
        Assert.equal(alice.calcSurplus(), 0, 'alice final surplus');

        Assert.equal(exchange.getBookLength(), 2, "book length");
    }

    function testMultipleLiquidationsWhenIssuerLacksCollateral() public {
        
        int step = 80e8;

        uint mu = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), mu);
        uint id = bob.writeOption(CALL, ethInitialPrice, 10 days);

        bob.transferOptions(address(alice), id, 1);

        feed.setPrice(ethInitialPrice + 1 * step);
        uint v1 = exchange.liquidateOptions(id);
        Assert.isTrue(v1 > 0, 'liquidation value t1');
        Assert.equal(bob.balance(), mu - v1, 'bob balance t1');
        MoreAssert.equal(bob.calcCollateral(), mu - v1, cBase, 'bob collateral t1');

        feed.setPrice(ethInitialPrice + 2 * step);
        uint v2 = exchange.liquidateOptions(id);
        Assert.isTrue(v2 > 0, 'liquidation value t2');
        Assert.equal(bob.balance(), mu - v1 - v2, 'bob balance t2');
        MoreAssert.equal(bob.calcCollateral(), mu - v1 - v2, cBase, 'bob collateral t2');

        feed.setPrice(ethInitialPrice + 3 * step);
        uint v3 = exchange.liquidateOptions(id);
        Assert.isTrue(v3 > 0, 'liquidation value t3');
        Assert.equal(bob.balance(), mu - v1 - v2 - v3, 'bob balance t3');
        MoreAssert.equal(bob.calcCollateral(), mu - v1 - v2 - v3, cBase, 'bob collateral t3');

        Assert.equal(exchange.getBookLength(), 2, "book length");
    }

    function testLiquidationAtMaturityOTM() public {
        
        int step = 40e8;

        uint mu = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), mu);
        uint id = bob.writeOption(CALL, ethInitialPrice, 10 days);
        
        bob.transferOptions(address(alice), id, 1);

        feed.setPrice(ethInitialPrice - step);
        time.setTimeOffset(10 days);

        Assert.equal(bob.calcCollateral(), 0, 'bob collateral before liquidation');

        alice.liquidateOptions(id);

        Assert.equal(bob.calcCollateral(), 0, 'bob final collateral');
        Assert.equal(alice.calcCollateral(), 0, 'alice final collateral');

        Assert.equal(bob.calcSurplus(), mu, 'bob final surplus');
        Assert.equal(alice.calcSurplus(), 0, 'alice final surplus');
    }

    function testLiquidationAtMaturityITM() public {
        
        int step = 40e8;

        uint mu = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), mu);
        uint id = bob.writeOption(PUT, ethInitialPrice, 10 days);
        
        bob.transferOptions(address(alice), id, 1);

        feed.setPrice(ethInitialPrice - step);
        time.setTimeOffset(10 days);

        uint iv = uint(exchange.calcIntrinsicValue(id));

        Assert.equal(bob.calcCollateral(), iv, 'bob collateral before liquidation');

        alice.liquidateOptions(id);

        Assert.equal(iv, uint(step), 'intrinsic value');

        Assert.equal(bob.calcCollateral(), 0, 'bob final collateral');
        Assert.equal(alice.calcCollateral(), 0, 'alice final collateral');

        Assert.equal(bob.calcSurplus(), mu - iv, 'bob final surplus');
        Assert.equal(alice.calcSurplus(), 0, 'alice final surplus');
    }
}