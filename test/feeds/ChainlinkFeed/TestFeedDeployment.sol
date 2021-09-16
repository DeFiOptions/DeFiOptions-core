pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestFeedDeployment is Base {

    uint[] timestamps3d;
    int[] prices3d;

    function testRequestValidData() public {

        AggregatorV3Mock mock = new AggregatorV3Mock(roundIds, answers, updatedAts);

        timestamps3d = [1 days, 2 days, 3 days];
        prices3d = [prices[0], prices[1], prices[2]];

        feed = new ChainlinkFeed(
            "ETH/USD",
            address(0),
            address(mock), 
            address(time),
            0,
            timestamps3d, 
            prices3d
        );
        
        (, price, cached) = feed.getPriceCached(1 days);
        Assert.equal(price, prices[0], "getPriceCached 1");
        Assert.isTrue(cached, "cached 1");

        (, price, cached) = feed.getPriceCached(2 days);
        Assert.equal(price, prices[1], "getPriceCached 2");
        Assert.isTrue(cached, "cached 2");

        (, price, cached) = feed.getPriceCached(2 days + 12 hours);
        Assert.equal(price, prices[2], "getPriceCached 2.5");
        Assert.isFalse(cached, "cached 2.5");

        (, price, cached) = feed.getPriceCached(3 days);
        Assert.equal(price, prices[2], "getPriceCached 3");
        Assert.isTrue(cached, "cached 3");
    }

    function testRequestInvalidData() public {

        AggregatorV3Mock mock = new AggregatorV3Mock(roundIds, answers, updatedAts);

        timestamps3d = [1 days, 2 days, 3 days];
        prices3d = [prices[0], prices[1], prices[2]];

        feed = new ChainlinkFeed(
            "ETH/USD",
            address(0),
            address(mock), 
            address(time),
            0,
            timestamps3d, 
            prices3d
        );

        (bool success,) = address(feed).call(
            abi.encodePacked(
                feed.getPriceCached.selector,
                abi.encode(4 days)
            )
        );
        
        Assert.isFalse(success, "getPriceCached should fail");
    }
}