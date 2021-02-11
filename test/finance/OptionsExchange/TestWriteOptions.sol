pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/actors/OptionsTrader.sol";
import "../../common/utils/MoreAssert.sol";

contract TestWriteOptions is Base {

    function testWriteWithoutCollateral() public {
        
        (bool success,) = address(bob).call(
            abi.encodePacked(
                bob.writeOption.selector,
                abi.encode(CALL, ethInitialPrice, 10)
            )
        );
        
        Assert.isFalse(success, "issue should fail");
    }

    function testWriteAndSequentialTransfers() public {

        int step = 40e8;
        uint ct = MoreMath.sqrtAndMultiply(15, upperVol);
        
        depositTokens(address(bob), 5000 finney);

        uint id = bob.writeOptions(10, CALL, ethInitialPrice - step, 15 days);
        MoreAssert.equal(bob.calcCollateral(), 10 * ct, cBase, "collateral none transfered");

        bob.transferOptions(address(alice), id, 1);
        MoreAssert.equal(bob.calcCollateral(), 10 * ct + 1 * uint(step), cBase, "collateral '1' transfered");

        bob.transferOptions(address(alice), id, 2);
        MoreAssert.equal(bob.calcCollateral(), 10 * ct + 3 * uint(step), cBase, "collateral '3' transfered");

        bob.transferOptions(address(alice), id, 3);
        MoreAssert.equal(bob.calcCollateral(), 10 * ct + 6 * uint(step), cBase, "collateral '6' transfered");

        OptionToken tk = OptionToken(exchange.resolveToken(id));
        
        Assert.equal(tk.writtenVolume(address(bob)), 10 * volumeBase, "bob written volume");
        Assert.equal(tk.balanceOf(address(bob)), 4 * volumeBase, "bob options");
        Assert.equal(tk.writtenVolume(address(alice)), 0, "alice written volume");
        Assert.equal(tk.balanceOf(address(alice)), 6 * volumeBase, "alice options");
        Assert.equal(tk.totalSupply(), 10 * volumeBase, "total supply");

        Assert.equal(exchange.getBookLength(), 2, "book length");
    }

    function testWriteAndDistribute() public {

        uint ct = exchange.calcCollateral(
            address(0), 
            1100 * volumeBase, 
            CALL, 
            uint(ethInitialPrice), 
            time.getNow() + 30 days
        );
        depositTokens(address(bob), ct);
        uint id = bob.writeOptions(1100, CALL, ethInitialPrice, 30 days);

        Assert.equal(exchange.getBookLength(), 1, "book length t0");

        OptionsTrader h1 = new OptionsTrader(address(exchange), address(time));
        OptionsTrader h2 = new OptionsTrader(address(exchange), address(time));
        OptionsTrader h3 = new OptionsTrader(address(exchange), address(time));
        OptionsTrader h4 = new OptionsTrader(address(exchange), address(time));

        bob.transferOptions(address(h1), id, 100);
        bob.transferOptions(address(h2), id, 200);
        bob.transferOptions(address(h3), id, 300);
        bob.transferOptions(address(h4), id, 400);

        OptionToken tk = OptionToken(exchange.resolveToken(id));

        Assert.equal(tk.balanceOf(address(bob)), 100 * volumeBase, "bob options");
        Assert.equal(tk.balanceOf(address(h1)), 100 * volumeBase, "h1 options");
        Assert.equal(tk.balanceOf(address(h2)), 200 * volumeBase, "h2 options");
        Assert.equal(tk.balanceOf(address(h3)), 300 * volumeBase, "h3 options");
        Assert.equal(tk.balanceOf(address(h4)), 400 * volumeBase, "h4 options");

        Assert.equal(exchange.getBookLength(), 5, "book length t1");

        h1.transferOptions(address(h2), id, 100);
        h3.transferOptions(address(h2), id, 100);
        h4.transferOptions(address(h2), id, 100);

        Assert.equal(tk.balanceOf(address(bob)), 100 * volumeBase, "bob options");
        Assert.equal(tk.balanceOf(address(h1)), 0, "h1 options");
        Assert.equal(tk.balanceOf(address(h2)), 500 * volumeBase, "h2 options");
        Assert.equal(tk.balanceOf(address(h3)), 200 * volumeBase, "h3 options");
        Assert.equal(tk.balanceOf(address(h4)), 300 * volumeBase, "h4 options");

        Assert.equal(tk.writtenVolume(address(bob)), 1100 * volumeBase, "bob written volume");
        Assert.equal(exchange.getBookLength(), 4, "book length t2");
    }

    function testWriteAndBurn() public {

        int step = 40e8;
        uint ct = MoreMath.sqrtAndMultiply(15, upperVol);
        
        depositTokens(address(bob), 5000 finney);

        uint id = bob.writeOptions(10, CALL, ethInitialPrice - step, 15 days);

        bob.transferOptions(address(alice), id, 5);
        MoreAssert.equal(bob.calcCollateral(), 10 * ct + 5 * uint(step), cBase, "collateral before burn");

        OptionToken tk = OptionToken(exchange.resolveToken(id));

        Assert.equal(tk.writtenVolume(address(bob)), 10 * volumeBase, "bob written volume");
        Assert.equal(tk.balanceOf(address(bob)), 5 * volumeBase, "bob options");
        Assert.equal(tk.balanceOf(address(alice)), 5 * volumeBase, "alice options");
        Assert.equal(tk.totalSupply(), 10 * volumeBase, "total supply");

        bob.burnOptions(id, 5);

        MoreAssert.equal(bob.calcCollateral(), 5 * ct + 5 * uint(step), cBase, "collateral after burn");

        Assert.equal(tk.writtenVolume(address(bob)), 5 * volumeBase, "bob written volume");
        Assert.equal(tk.balanceOf(address(bob)), 0, "bob options");
        Assert.equal(tk.balanceOf(address(alice)), 5 * volumeBase, "alice options");
        Assert.equal(tk.totalSupply(), 5 * volumeBase, "total supply");

        Assert.equal(exchange.getBookLength(), 2, "book length");
    }

    function testWriteSameMultipleTimes() public {

        uint ct = exchange.calcCollateral(
            address(0), 
            300 * volumeBase, 
            CALL, 
            uint(ethInitialPrice), 
            time.getNow() + 30 days
        );
        depositTokens(address(bob), ct);

        OptionsTrader h1 = new OptionsTrader(address(exchange), address(time));

        uint id1 = bob.writeOptions(100, CALL, ethInitialPrice, 30 days);
        OptionToken tk = OptionToken(exchange.resolveToken(id1));
        Assert.equal(tk.writtenVolume(address(bob)), 100 * volumeBase, "bob written volume");
        bob.transferOptions(address(h1), id1, 100);

        uint id2 = bob.writeOptions(100, CALL, ethInitialPrice, 30 days);
        Assert.equal(tk.writtenVolume(address(bob)), 200 * volumeBase, "bob written volume");
        bob.transferOptions(address(h1), id2, 100);

        uint id3 = bob.writeOptions(100, CALL, ethInitialPrice, 30 days);
        Assert.equal(tk.writtenVolume(address(bob)), 300 * volumeBase, "bob written volume");
        bob.transferOptions(address(h1), id3, 100);
        
        Assert.equal(id1, id2, "same Id (2)");
        Assert.equal(id1, id3, "same Id (3)");

        Assert.equal(tk.balanceOf(address(bob)), 0, "bob options");
        Assert.equal(tk.balanceOf(address(h1)), 300 * volumeBase, "h1 options");
        Assert.equal(exchange.getBookLength(), 2, "book length");
    }
}