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

        Assert.equal(vol5d, calcVol5d(), 'vol 5d');
        Assert.equal(vol10d, calcVol10d(), 'vol 10d');
    }

    function testGetDailyVolatilityAfterPrefetching() public {

        for (uint i = 1; i <= 10; i++) {
            feed.prefetchDailyPrice(i);
        }

        feed.prefetchDailyVolatility(10 days);

        (uint vol5d, bool c5) = feed.getDailyVolatilityCached(5 days);
        (uint vol10d, bool c10) = feed.getDailyVolatilityCached(10 days);

        Assert.equal(vol5d, calcVol5d(), 'vol 5d');
        Assert.equal(vol10d, calcVol10d(), 'vol 10d');

        Assert.isFalse(c5, 'cached 5d');
        Assert.isTrue(c10, 'cached 10d');
    }

    function calcVol5d() private returns(uint vol) {

        array5d = [
            (pBase * answers[6]) / answers[5],
            (pBase * answers[7]) / answers[6],
            (pBase * answers[8]) / answers[7],
            (pBase * answers[9]) / answers[8]
        ];

        vol = (uint(answers[9]) * MoreMath.std(array5d)) / uint(pBase);
    }

    function calcVol10d() private returns(uint vol) {
        
        array10d = [
            (pBase * answers[1]) / answers[0],
            (pBase * answers[2]) / answers[1],
            (pBase * answers[3]) / answers[2],
            (pBase * answers[4]) / answers[3],
            (pBase * answers[5]) / answers[4],
            (pBase * answers[6]) / answers[5],
            (pBase * answers[7]) / answers[6],
            (pBase * answers[8]) / answers[7],
            (pBase * answers[9]) / answers[8]
        ];

        vol = (uint(answers[9]) * MoreMath.std(array10d)) / uint(pBase);
    }
}