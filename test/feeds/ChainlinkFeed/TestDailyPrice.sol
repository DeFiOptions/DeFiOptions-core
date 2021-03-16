pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestDailyPrice is Base {

    function testGetPriceAfterPrefetching() public {

        feed.prefetchDailyPrice(1);
        feed.prefetchDailyPrice(2);
        feed.prefetchDailyPrice(3);
        feed.prefetchDailyPrice(5);
        feed.prefetchDailyPrice(8);
        
        (, price, cached) = feed.getPriceCached(1 days);
        Assert.equal(price, prices[0], "getPriceCached 1");
        Assert.isTrue(cached, "cached 1");

        (, price, cached) = feed.getPriceCached(2 days);
        Assert.equal(price, prices[1], "getPriceCached 2");
        Assert.isTrue(cached, "cached 2");

        (, price, cached) = feed.getPriceCached(3 days);
        Assert.equal(price, prices[2], "getPriceCached 3");
        Assert.isTrue(cached, "cached 3");

        (, price, cached) = feed.getPriceCached(4 days);
        Assert.equal(price, prices[4], "getPriceCached 4");
        Assert.isFalse(cached, "cached 4");

        (, price, cached) = feed.getPriceCached(5 days);
        Assert.equal(price, prices[4], "getPriceCached 5");
        Assert.isTrue(cached, "cached 5");

        (, price, cached) = feed.getPriceCached(6 days);
        Assert.equal(price, prices[7], "getPriceCached 6");
        Assert.isFalse(cached, "cached 6");

        (, price, cached) = feed.getPriceCached(7 days);
        Assert.equal(price, prices[7], "getPriceCached 7");
        Assert.isFalse(cached, "cached 7");

        (, price, cached) = feed.getPriceCached(8 days);
        Assert.equal(price, prices[7], "getPriceCached 8");
        Assert.isTrue(cached, "cached 8");
    }
}