pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestCreditTokenIssuance is Base {
    
    uint public initialBalance = 10 ether;

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
}