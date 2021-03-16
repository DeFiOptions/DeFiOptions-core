pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../../contracts/utils/MoreMath.sol";

contract TestExpectedPayout is Base {

    function testSingleOptionExpectedPayout() public {

        int step = 30e18;
        depositTokens(address(bob), upperVol);

        uint id = bob.writeOption(CALL, ethInitialPrice, 1 days);
        bob.transferOptions(address(alice), id, 1);

        feed.setPrice(ethInitialPrice - step);
        Assert.equal(exchange.calcExpectedPayout(address(bob)), 0, "bob payout below strike");
        Assert.equal(exchange.calcExpectedPayout(address(alice)), 0, "alice payout below strike");

        feed.setPrice(ethInitialPrice);
        Assert.equal(exchange.calcExpectedPayout(address(bob)), 0, "bob payout at strike");
        Assert.equal(exchange.calcExpectedPayout(address(alice)), 0, "alice payout at strike");
        
        feed.setPrice(ethInitialPrice + step);
        Assert.equal(exchange.calcExpectedPayout(address(bob)), -step, "bob payout above strike");
        Assert.equal(exchange.calcExpectedPayout(address(alice)), step, "alice payout above strike");
    }

    function testOptionsPortifolioExpectedPayout() public {

        int step = 30e18;
        depositTokens(address(bob), 15 * upperVol);
        
        uint id1 = bob.writeOptions(3, CALL, ethInitialPrice, 5 days);
        bob.transferOptions(address(alice), id1, 3);
        
        uint id2 = bob.writeOption(PUT, ethInitialPrice + step, 5 days);
        bob.transferOptions(address(alice), id2, 1);

        feed.setPrice(ethInitialPrice - step);
        Assert.equal(exchange.calcExpectedPayout(address(bob)), -2 * step, "bob payout below strike");
        Assert.equal(exchange.calcExpectedPayout(address(alice)), 2 * step, "alice payout below strike");

        feed.setPrice(ethInitialPrice);
        Assert.equal(exchange.calcExpectedPayout(address(bob)), -step, "bob payout at strike");
        Assert.equal(exchange.calcExpectedPayout(address(alice)), step, "alice payout at strike");
        
        feed.setPrice(ethInitialPrice + step);
        Assert.equal(exchange.calcExpectedPayout(address(bob)), -3 * step, "bob payout above strike");
        Assert.equal(exchange.calcExpectedPayout(address(alice)), 3 * step, "alice payout above strike");
    }
}