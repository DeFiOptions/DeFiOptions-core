pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/utils/MoreMath.sol";

contract TestMoreMath {

    function testPowAndMultiply() public {

        Assert.equal(MoreMath.powAndMultiply(11, 10, 10, 1), 1, "powAndMultiply f=1");
        Assert.equal(MoreMath.powAndMultiply(11, 10, 10, 1e1), 22, "powAndMultiply f=1e1");
        Assert.equal(MoreMath.powAndMultiply(11, 10, 10, 1e2), 256, "powAndMultiply f=1e2");
        Assert.equal(MoreMath.powAndMultiply(11, 10, 10, 1e3), 2592, "powAndMultiply f=1e3");
        Assert.equal(MoreMath.powAndMultiply(11, 10, 10, 1e4), 25937, "powAndMultiply f=1e4");
        Assert.equal(MoreMath.powAndMultiply(11, 10, 10, 1e12), 2593742460100, "powAndMultiply f=1e12");
    }

    function testPow() public {
        
        Assert.equal(MoreMath.pow(2, 0), 1, "pow 2,0");
        Assert.equal(MoreMath.pow(2, 1), 2, "pow 2,1");
        Assert.equal(MoreMath.pow(2, 2), 4, "pow 2,2");
        Assert.equal(MoreMath.pow(2, 3), 8, "pow 2,3");
        Assert.equal(MoreMath.pow(5, 10), 9765625, "pow 5,10");
    }

    function testPowDecimal() public {
        
        uint b = 1e9;
        Assert.equal(MoreMath.powDecimal(2e9, 15e8, b), 2823125404, "pow 2^1.50");
        Assert.equal(MoreMath.powDecimal(2e9, 50e7, b), 1411562702, "pow 2^0.50");
        Assert.equal(MoreMath.powDecimal(2e9, 77e7, b), 1703641918, "pow 2^0.77");
        Assert.equal(MoreMath.powDecimal(2e9, 30e7, b), 1229973362, "pow 2^0.30");
        Assert.equal(MoreMath.powDecimal(2e9, 3e7, b),  1020119746, "pow 2^0.03");
        Assert.equal(MoreMath.powDecimal(1024e9, 10e7, b), 1998000721, "pow 1024^0.1");
        Assert.equal(MoreMath.powDecimal(89021e9, 6612e5, b), 1871857777773, "pow 89021^0.6612");
    }

    function testSqrtAndMultiply() public {
        
        Assert.equal(MoreMath.sqrtAndMultiply(1, 5), 5, "sqrtAndMultiply 1, 5");
        Assert.equal(MoreMath.sqrtAndMultiply(9, 3), 9, "sqrtAndMultiply 9, 3");
        Assert.equal(MoreMath.sqrtAndMultiply(2, 1e10), 14142135620, "sqrtAndMultiply 2, 1e10");
        Assert.equal(MoreMath.sqrtAndMultiply(653628690, 10), 255661, "sqrtAndMultiply 653628690, 10");
    }

    function testSqrt() public {
        
        Assert.equal(MoreMath.sqrt(1), 1, "sqrt 1");
        Assert.equal(MoreMath.sqrt(9), 3, "sqrt 9");
        Assert.equal(MoreMath.sqrt(16), 4, "sqrt 16");
        Assert.equal(MoreMath.sqrt(653628690), 25566, "sqrt 653628690");
    }

    function testStd() public {

        int[] memory a = new int[](8);
        a[0] = 10e10;
        a[1] = 12e10;
        a[2] = 23e10;
        a[3] = 23e10;
        a[4] = 16e10;
        a[5] = 23e10;
        a[6] = 21e10;
        a[7] = 16e10;
        Assert.equal(MoreMath.std(a), 48989794855, "std");
    }

    function testToString() public {

        Assert.equal(MoreMath.toString(0), "0", "0");
        Assert.equal(MoreMath.toString(1), "1", "1");
        Assert.equal(MoreMath.toString(123), "123", "123");
        Assert.equal(MoreMath.toString(107680546035), "107680546035", "107680546035");
        Assert.equal(MoreMath.toString(1e9), "1e9", "1e9");
        Assert.equal(MoreMath.toString(1 ether), "1e18", "1 ether");
        Assert.equal(MoreMath.toString(550e8), "55e9", "55e9");
    }
}