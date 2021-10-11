pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestBinarySearch is Base {

    uint e = 1;
    uint step = 10;

    function testBinarySearchExact() public {

        initialize();
        
        (, price, cached) = feed.getPriceCached(1 days + e);
        Assert.equal(price, prices[0], "getPriceCached 1");
        Assert.isFalse(cached, "cached 1");

        (, price, cached) = feed.getPriceCached(2 days + e);
        Assert.equal(price, prices[1], "getPriceCached 2");
        Assert.isFalse(cached, "cached 2");

        (, price, cached) = feed.getPriceCached(3 days + e);
        Assert.equal(price, prices[2], "getPriceCached 3");
        Assert.isFalse(cached, "cached 3");

        (, price, cached) = feed.getPriceCached(4 days + e);
        Assert.equal(price, prices[3], "getPriceCached 4");
        Assert.isFalse(cached, "cached 4");

        (, price, cached) = feed.getPriceCached(5 days + e);
        Assert.equal(price, prices[4], "getPriceCached 5");
        Assert.isFalse(cached, "cached 5");

        (, price, cached) = feed.getPriceCached(6 days + e);
        Assert.equal(price, prices[5], "getPriceCached 6");
        Assert.isFalse(cached, "cached 6");

        (, price, cached) = feed.getPriceCached(7 days + e);
        Assert.equal(price, prices[6], "getPriceCached 7");
        Assert.isFalse(cached, "cached 7");

        (, price, cached) = feed.getPriceCached(8 days + e);
        Assert.equal(price, prices[7], "getPriceCached 8");
        Assert.isFalse(cached, "cached 8");

        (, price, cached) = feed.getPriceCached(9 days + e);
        Assert.equal(price, prices[8], "getPriceCached 9");
        Assert.isFalse(cached, "cached 9");

        (, price, cached) = feed.getPriceCached(10 days + e);
        Assert.equal(price, prices[9], "getPriceCached 10");
        Assert.isFalse(cached, "cached 10");
    }

    function testBinarySearchNotExact() public {

        initialize();

        (, price, cached) = feed.getPriceCached(1 days + step);
        Assert.equal(price, prices[1], "getPriceCached 2");
        Assert.isFalse(cached, "cached 2");

        (, price, cached) = feed.getPriceCached(3 days - step);
        Assert.equal(price, prices[2], "getPriceCached 3");
        Assert.isFalse(cached, "cached 3");

        (, price, cached) = feed.getPriceCached(3 days + step);
        Assert.equal(price, prices[3], "getPriceCached 4");
        Assert.isFalse(cached, "cached 4");

        (, price, cached) = feed.getPriceCached(5 days - step);
        Assert.equal(price, prices[4], "getPriceCached 5");
        Assert.isFalse(cached, "cached 5");

        (, price, cached) = feed.getPriceCached(5 days + step);
        Assert.equal(price, prices[5], "getPriceCached 6");
        Assert.isFalse(cached, "cached 6");

        (, price, cached) = feed.getPriceCached(7 days - step);
        Assert.equal(price, prices[6], "getPriceCached 7");
        Assert.isFalse(cached, "cached 7");

        (, price, cached) = feed.getPriceCached(7 days + step);
        Assert.equal(price, prices[7], "getPriceCached 8");
        Assert.isFalse(cached, "cached 8");
    }

    function testInvalidInitialPosition() public {

        initialize();

        (bool success,) = address(feed).call(
            abi.encodePacked(
                feed.getPriceCached.selector,
                abi.encode(1 days - step)
            )
        );
        
        Assert.isFalse(success, "getPriceCached should fail");
    }

    function testInvalidFinalPosition() public {

        initialize();

        (bool success,) = address(feed).call(
            abi.encodePacked(
                feed.getPriceCached.selector,
                abi.encode(10 days + step)
            )
        );
        
        Assert.isFalse(success, "getPriceCached should fail");
    }

    function initialize() private {

        for (uint i = 0; i < updatedAts.length; i ++) {
            updatedAts[i] += e; // to prevent caching
        }
        feed.initialize(updatedAts, prices);
    }
}