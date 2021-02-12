pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestCreditTokenIssuance is Base {

    function testIssueTokens() public {
        
        issuer.issueTokens(address(alpha), 100 finney);
        Assert.equal(creditToken.balanceOf(address(alpha)), 100 finney, "alpha credit");
        Assert.equal(creditToken.balanceOf(address(beta)), 0 finney, "beta credit");
    }

    function testTransferTokens() public {
        
        issuer.issueTokens(address(alpha), 100 finney);
        alpha.transfer(address(beta), 20 finney);
        Assert.equal(creditToken.balanceOf(address(alpha)), 80 finney, "alpha credit");
        Assert.equal(creditToken.balanceOf(address(beta)), 20 finney, "beta credit");
    }

    function testIssueHoldAndTransfer() public {
        
        issuer.issueTokens(address(alpha), 100 finney);

        uint c1 = creditToken.balanceOf(address(alpha));
        Assert.equal(c1, 100 finney, "alpha credit");

        uint ts1 = creditToken.totalSupply();
        Assert.equal(ts1, 100 finney, "initial supply");
        
        time.setTimeOffset(1 days);
        uint c2 = creditToken.balanceOf(address(alpha));
        Assert.isTrue(c2 > c1, "interest accrual");

        alpha.transfer(address(beta), c2);
        uint c3 = creditToken.balanceOf(address(alpha));
        Assert.equal(c3, 0, "alpha credit after burn");

        uint ts2 = creditToken.totalSupply();
        Assert.equal(ts2, c2, "final supply");
    }
}