pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";

contract TestExchangeDeposit is Base {

    function testBalances() public {

        uint vBase = 1e24;
        
        Assert.equal(bob.calcSurplus(), 0, "bob initial surplus");
        Assert.equal(alice.calcSurplus(), 0, "alice initial surplus");
        
        depositTokens(address(bob), 10 * vBase);
        Assert.equal(erc20.balanceOf(address(bob)), 0, "bob balance");
        Assert.equal(erc20.balanceOf(address(creditProvider)), 10 * vBase, "creditProvider balance");
        
        depositTokens(address(alice), 50 * vBase);
        Assert.equal(erc20.balanceOf(address(alice)), 0, "alice balance");
        Assert.equal(erc20.balanceOf(address(creditProvider)), 60 * vBase, "creditProvider balance");
        
        Assert.equal(bob.calcSurplus(), 10 * vBase, "bob final surplus");
        Assert.equal(alice.calcSurplus(), 50 * vBase, "alice final surplus");
    }
    
    function testSurplus() public {

        uint vBase = 1e24;

        int step = 40e18;
        depositTokens(address(bob), 1500 * vBase);

        address _tk1 = bob.writeOption(CALL, ethInitialPrice - step, 10 days);
        bob.transferOptions(address(alice), _tk1, 1);

        address _tk2 = bob.writeOption(CALL, ethInitialPrice + step, 10 days);
        bob.transferOptions(address(alice), _tk2, 1);

        uint ct1 = MoreMath.sqrtAndMultiply(10, upperVol) + uint(step);
        uint ct2 = MoreMath.sqrtAndMultiply(10, upperVol);

        uint sp = 1500 * vBase - ct1 - ct2 ;
        MoreAssert.equal(bob.calcSurplus(), sp, cBase, "check surplus");

        bob.withdrawTokens();
        Assert.equal(bob.calcSurplus(), 0, "check surplus after withdraw");
        MoreAssert.equal(erc20.balanceOf(address(bob)), sp, cBase, "check tokens after withdraw");
    }
}