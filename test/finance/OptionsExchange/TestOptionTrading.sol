pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";
import "./Base.sol";

contract TestOptionTrading is Base {

    uint creditIr;
    uint creditBase;
    
    uint debtIr;
    uint debtBase;

    function testCreditTokenIssuance() public {

        uint ct5 = MoreMath.sqrtAndMultiply(5, upperVol);
        uint ct10 = MoreMath.sqrtAndMultiply(10, upperVol);

        depositTokens(address(bob), ct10);
        address _tk1 = bob.writeOption(CALL, ethInitialPrice, 10 days);
        bob.transferOptions(address(alice), _tk1, 1);

        time.setTimeOffset(5 days);

        depositTokens(address(alice), ct10);
        address _tk2 = alice.writeOption(CALL, ethInitialPrice, 10 days);
        alice.transferOptions(address(bob), _tk2, 1);
        
        int step = ethInitialPrice;
        feed.setPrice(ethInitialPrice + step);
        time.setTimeOffset(10 days);
        
        liquidateAndRedeem(_tk1);
        feed.setPrice(ethInitialPrice);
        
        alice.withdrawTokens();
        bob.withdrawTokens();

        Assert.isTrue(uint(step) > ct10, "unsufficient collateral expected");

        Assert.equal(erc20.balanceOf(address(bob)), 0, "bob balance");
        Assert.equal(erc20.balanceOf(address(alice)), 2 * ct10, "alice balance");
        Assert.equal(creditProvider.totalTokenStock(), 0, "token stock");

        Assert.equal(creditToken.balanceOf(address(bob)), 0, "bob tokens");
        Assert.equal(creditToken.balanceOf(address(alice)), uint(step) - ct5 - ct10, "alice tokens");
        
        Assert.equal(getBookLength(), 2, "book length");
    }

    function testDebtInterestRate() public {

        uint ct = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), ct);
        address _tk1 = bob.writeOption(CALL, ethInitialPrice, 10 days);
        bob.transferOptions(address(alice), _tk1, 1);

        time.setTimeOffset(5 days);

        depositTokens(address(alice), ct);
        address _tk2 = alice.writeOption(CALL, ethInitialPrice, 10 days);
        alice.transferOptions(address(bob), _tk2, 1);
        
        int step = ethInitialPrice;
        feed.setPrice(ethInitialPrice + step);
        time.setTimeOffset(10 days);
        
        liquidateAndRedeem(_tk1);

        (debtIr, debtBase,) = settings.getDebtInterestRate();
        uint debt = uint(step) - ct;

        uint d1 = bob.calcDebt();
        Assert.equal(d1, debt, "debt without interest");

        time.setTimeOffset(20 days);
        uint d2 = bob.calcDebt();
        uint debt10 = MoreMath.powAndMultiply(debtIr, debtBase, 10 days / timeBase, debt);
        MoreAssert.equal(d2, debt10, cBase, "debt with 10 day interest");
        
        time.setTimeOffset(30 days);
        uint d3 = bob.calcDebt();
        uint debt20 = MoreMath.powAndMultiply(debtIr, debtBase, 20 days / timeBase, debt);
        MoreAssert.equal(d3, debt20, cBase, "debt with 20 day interest");

        Assert.equal(getBookLength(), 2, "book length");
    }

    function testDebtSettlementEarlyWithdraw() public {

        uint ct5 = MoreMath.sqrtAndMultiply(5, upperVol);
        uint ct10 = MoreMath.sqrtAndMultiply(10, upperVol);

        depositTokens(address(bob), ct10);
        address _tk1 = bob.writeOption(CALL, ethInitialPrice, 10 days);
        bob.transferOptions(address(alice), _tk1, 1);

        time.setTimeOffset(5 days);

        depositTokens(address(alice), ct10);
        address _tk2 = alice.writeOption(CALL, ethInitialPrice, 10 days);
        alice.transferOptions(address(bob), _tk2, 1);
        
        int step = 4 * ethInitialPrice;
        feed.setPrice(ethInitialPrice + step);
        time.setTimeOffset(10 days);
        
        liquidateAndRedeem(_tk1);

        alice.withdrawTokens();

        time.setTimeOffset(15 days);

        liquidateAndRedeem(_tk2);

        bob.withdrawTokens();

        (debtIr, debtBase,) = settings.getDebtInterestRate();
        uint debt = MoreMath.powAndMultiply(debtIr, debtBase, 5 days / timeBase, uint(step) - ct10);

        Assert.equal(bob.calcDebt(), 0, "bob debt");
        Assert.equal(alice.calcDebt(), 0, "alice debt");
        
        Assert.equal(erc20.balanceOf(address(bob)), uint(step) - debt, "bob balance");
        Assert.equal(erc20.balanceOf(address(alice)), ct10 - ct5, "alice balance");

        Assert.equal(creditToken.balanceOf(address(bob)), 0, "bob tokens");
        Assert.equal(creditToken.balanceOf(address(alice)), 0, "alice tokens");

        Assert.equal(creditProvider.totalTokenStock(), ct5 + debt - (uint(step) - ct10), "token stock");

        Assert.equal(getBookLength(), 0, "book length");
    }

    function testDebtSettlementLateWithdraw() public {

        uint ct = MoreMath.sqrtAndMultiply(10, upperVol);
        depositTokens(address(bob), ct);
        address _tk1 = bob.writeOption(CALL, ethInitialPrice, 10 days);
        bob.transferOptions(address(alice), _tk1, 1);

        time.setTimeOffset(5 days);

        depositTokens(address(alice), ct);
        address _tk2 = alice.writeOption(CALL, ethInitialPrice, 10 days);
        alice.transferOptions(address(bob), _tk2, 1);
        
        int step = 4 * ethInitialPrice;
        feed.setPrice(ethInitialPrice + step);
        time.setTimeOffset(10 days);
        
        liquidateAndRedeem(_tk1);

        time.setTimeOffset(15 days);

        liquidateAndRedeem(_tk2);

        alice.withdrawTokens();
        bob.withdrawTokens();

        (debtIr, debtBase,) = settings.getDebtInterestRate();
        uint debt = MoreMath.powAndMultiply(debtIr, debtBase, 5 days / timeBase, uint(step) - ct);

        Assert.equal(bob.calcDebt(), 0, "bob debt");
        Assert.equal(alice.calcDebt(), 0, "alice debt");
        
        Assert.equal(erc20.balanceOf(address(bob)), uint(step) - debt, "bob balance");
        Assert.equal(erc20.balanceOf(address(alice)), ct, "alice balance");

        Assert.equal(creditToken.balanceOf(address(bob)), 0, "bob tokens");
        Assert.equal(creditToken.balanceOf(address(alice)), 0, "alice tokens");

        Assert.equal(creditProvider.totalTokenStock(), ct - uint(step) + debt, "token stock");

        Assert.equal(getBookLength(), 0, "book length");
    }

    function testWriteBurnAndRedeem() public {

        uint ct = exchange.calcCollateral(
            address(feed), 
            300 * volumeBase, 
            CALL, 
            uint(ethInitialPrice), 
            time.getNow() + 30 days
        );
        
        depositTokens(address(bob), ct);
        depositTokens(address(alice), ct);

        address _tk1 = bob.writeOptions(100, CALL, ethInitialPrice, 30 days);
        bob.transferOptions(address(alice), _tk1, 100);

        bob.writeOptions(100, CALL, ethInitialPrice, 30 days);
        bob.transferOptions(address(alice), _tk1, 100);

        bob.writeOptions(100, CALL, ethInitialPrice, 30 days);
        bob.transferOptions(address(alice), _tk1, 100);

        address _tk2 = alice.writeOptions(300, CALL, ethInitialPrice, 30 days);
        alice.transferOptions(address(bob), _tk2, 300);

        OptionToken tk = OptionToken(_tk1);

        Assert.equal(tk.totalSupply(), 600 * volumeBase, "total supply before burn");

        bob.burnOptions(_tk1, 300);
        alice.burnOptions(_tk2, 300);

        Assert.equal(tk.totalSupply(), 0, "total supply after burn");
        Assert.equal(tk.balanceOf(address(bob)), 0, "bob options");
        Assert.equal(tk.balanceOf(address(alice)), 0, "alice options");

        time.setTimeOffset(30 days);
        liquidateAndRedeem(address(tk));
        Assert.equal(getBookLength(), 0, "book length");
    }
}