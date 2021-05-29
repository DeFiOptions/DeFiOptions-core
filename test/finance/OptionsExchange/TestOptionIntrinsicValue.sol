pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";
import "./Base.sol";

contract TestOptionIntrinsicValue is Base {

    function testCallIntrinsictValue() public {

        int step = 30e18;
        depositTokens(address(bob), upperVol);
        address _tk = bob.writeOption(CALL, ethInitialPrice, 1 days);
        bob.transferOptions(address(alice), _tk, 1);

        feed.setPrice(ethInitialPrice - step);
        Assert.equal(int(exchange.calcIntrinsicValue(_tk)), 0, "quote below strike");

        feed.setPrice(ethInitialPrice);
        Assert.equal(int(exchange.calcIntrinsicValue(_tk)), 0, "quote at strike");
        
        feed.setPrice(ethInitialPrice + step);
        Assert.equal(int(exchange.calcIntrinsicValue(_tk)), step, "quote above strike");
        
        Assert.equal(bob.calcCollateral(), upperVol + uint(step), "call collateral");
    }

    function testPutIntrinsictValue() public {

        int step = 40e18;
        depositTokens(address(bob), upperVol);
        address _tk = bob.writeOption(PUT, ethInitialPrice, 1 days);
        bob.transferOptions(address(alice), _tk, 1);

        feed.setPrice(ethInitialPrice - step);
        Assert.equal(int(exchange.calcIntrinsicValue(_tk)), step, "quote below strike");

        feed.setPrice(ethInitialPrice);
        Assert.equal(int(exchange.calcIntrinsicValue(_tk)), 0, "quote at strike");
        
        feed.setPrice(ethInitialPrice + step);
        Assert.equal(int(exchange.calcIntrinsicValue(_tk)), 0, "quote above strike");
                
        Assert.equal(bob.calcCollateral(), upperVol, "put collateral");
    }

    function testCollateralAtDifferentMaturities() public {

        uint ct1 = MoreMath.sqrtAndMultiply(30, upperVol);
        depositTokens(address(bob), ct1);
        bob.writeOption(CALL, ethInitialPrice, 30 days);
        MoreAssert.equal(bob.calcCollateral(), ct1, cBase, "collateral at 30d");

        uint ct2 = MoreMath.sqrtAndMultiply(10, upperVol);
        time.setTimeOffset(20 days);
        MoreAssert.equal(bob.calcCollateral(), ct2, cBase, "collateral at 10d");

        uint ct3 = MoreMath.sqrtAndMultiply(5, upperVol);
        time.setTimeOffset(25 days);
        MoreAssert.equal(bob.calcCollateral(), ct3, cBase, "collateral at 5d");

        uint ct4 = MoreMath.sqrtAndMultiply(1, upperVol);
        time.setTimeOffset(29 days);
        MoreAssert.equal(bob.calcCollateral(), ct4, cBase, "collateral at 1d");
    }

    function testCollateralForDifferentStrikePrices() public {
        
        int step = 40e18;
        uint vBase = 1e24;

        depositTokens(address(bob), 1500 * vBase);

        address _tk1 = bob.writeOption(CALL, ethInitialPrice - step, 10 days);
        bob.transferOptions(address(alice), _tk1, 1);
        uint ct1 = MoreMath.sqrtAndMultiply(10, upperVol) + uint(step);
        MoreAssert.equal(bob.calcCollateral(), ct1, cBase, "collateral ITM");

        address _tk2 = bob.writeOption(CALL, ethInitialPrice + step, 10 days);
        bob.transferOptions(address(alice), _tk2, 1);
        uint ct2 = MoreMath.sqrtAndMultiply(10, upperVol);
        MoreAssert.equal(bob.calcCollateral(), ct1 + ct2, cBase, "collateral OTM");
    }
}