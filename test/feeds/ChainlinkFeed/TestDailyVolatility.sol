pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/utils/MoreMath.sol";
import "./Base.sol";

contract TestDailyVolatility is Base {

    int pBase = 1e9;
    int[] array5d;
    int[] array10d;

    function testGetDailyVolatilityWithoutPrefetching() public {

        for (uint i = 1; i <= 10; i++) {
            feed.prefetchDailyPrice(i);
        }

        uint vol5d = feed.getDailyVolatility(5 days);
        uint vol10d = feed.getDailyVolatility(10 days);

        Assert.equal(vol5d, calcVol5d(), "vol 5d");
        Assert.equal(vol10d, calcVol10d(), "vol 10d");
    }

    function testGetDailyVolatilityAfterPrefetching() public {

        for (uint i = 1; i <= 10; i++) {
            feed.prefetchDailyPrice(i);
        }

        feed.prefetchDailyVolatility(10 days);

        (uint vol5d, bool c5) = feed.getDailyVolatilityCached(5 days);
        (uint vol10d, bool c10) = feed.getDailyVolatilityCached(10 days);

        Assert.equal(vol5d, calcVol5d(), "vol 5d");
        Assert.equal(vol10d, calcVol10d(), "vol 10d");

        Assert.isFalse(c5, "cached 5d");
        Assert.isTrue(c10, "cached 10d");
    }

    function calcVol5d() private returns(uint vol) {

        array5d = [
            (pBase * prices[6]) / prices[5],
            (pBase * prices[7]) / prices[6],
            (pBase * prices[8]) / prices[7],
            (pBase * prices[9]) / prices[8]
        ];

        vol = (uint(prices[9]) * MoreMath.std(array5d)) / uint(pBase);
    }

    function calcVol10d() private returns(uint vol) {
        
        array10d = [
            (pBase * prices[1]) / prices[0],
            (pBase * prices[2]) / prices[1],
            (pBase * prices[3]) / prices[2],
            (pBase * prices[4]) / prices[3],
            (pBase * prices[5]) / prices[4],
            (pBase * prices[6]) / prices[5],
            (pBase * prices[7]) / prices[6],
            (pBase * prices[8]) / prices[7],
            (pBase * prices[9]) / prices[8]
        ];

        vol = (uint(prices[9]) * MoreMath.std(array10d)) / uint(pBase);
    }
}