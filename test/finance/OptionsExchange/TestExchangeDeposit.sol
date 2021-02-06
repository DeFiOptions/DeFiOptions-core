pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";

contract TestExchangeDeposit is Base {

    function testBalances() public {
        
        Assert.equal(bob.calcSurplus(), 0, 'bob initial surplus');
        Assert.equal(alice.calcSurplus(), 0, 'alice initial surplus');
        
        depositTokens(address(bob), 10 finney);
        Assert.equal(erc20.balanceOf(address(bob)), 0, 'bob balance');
        Assert.equal(erc20.balanceOf(address(creditProvider)), 10 finney, 'creditProvider balance');
        
        depositTokens(address(alice), 50 finney);
        Assert.equal(erc20.balanceOf(address(alice)), 0, 'alice balance');
        Assert.equal(erc20.balanceOf(address(creditProvider)), 60 finney, 'creditProvider balance');
        
        Assert.equal(bob.calcSurplus(), 10 finney, 'bob final surplus');
        Assert.equal(alice.calcSurplus(), 50 finney, 'alice final surplus');
    }
    
    function testSurplus() public {

        int step = 40e8;
        depositTokens(address(bob), 1500 finney);

        uint id1 = bob.writeOption(CALL, ethInitialPrice - step, 10 days);
        bob.transferOptions(address(alice), id1, 1);

        uint id2 = bob.writeOption(CALL, ethInitialPrice + step, 10 days);
        bob.transferOptions(address(alice), id2, 1);

        uint ct1 = MoreMath.sqrtAndMultiply(10, upperVol) + uint(step);
        uint ct2 = MoreMath.sqrtAndMultiply(10, upperVol);

        uint sp = 1500 finney - ct1 - ct2 ;
        MoreAssert.equal(bob.calcSurplus(), sp, cBase, "check surplus");

        bob.withdrawTokens();
        Assert.equal(bob.calcSurplus(), 0, "check surplus after withdraw");
        MoreAssert.equal(erc20.balanceOf(address(bob)), sp, cBase, 'check tokens after withdraw');
    }
}