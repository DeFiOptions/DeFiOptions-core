pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../../contracts/utils/MoreMath.sol";
import "../../common/utils/MoreAssert.sol";
import "./Base.sol";

contract TestCreditTokenInterestRate is Base {

    function testInterestRateAtDifferentDates() public {

        (uint ir, uint base,) = settings.getCreditInterestRate();
        
        issuer.issueTokens(address(alpha), 100 finney);
        Assert.equal(creditToken.balanceOf(address(alpha)), 100 finney, "alpha credit t0");
        Assert.equal(creditToken.balanceOf(address(beta)), 0 finney, "beta credit t0");
        
        time.setTimeOffset(365 days);
        alpha.transfer(address(beta), 50 finney);
        uint v1 = MoreMath.powAndMultiply(ir, base, 365 days / timeBase, 100 finney) - 50 finney;
        Assert.equal(creditToken.balanceOf(address(alpha)), v1, "alpha credit t1");
        Assert.equal(creditToken.balanceOf(address(beta)), 50 finney, "beta credit t1");

        time.setTimeOffset(730 days);
        uint v2 = MoreMath.powAndMultiply(ir, base, 365 days / timeBase, v1);
        uint v3 = MoreMath.powAndMultiply(ir, base, 365 days / timeBase, 50 finney);
        Assert.equal(creditToken.balanceOf(address(alpha)), v2, "alpha credit t2");
        Assert.equal(creditToken.balanceOf(address(beta)), v3, "beta credit t2");

        uint total = MoreMath.powAndMultiply(ir, base, 730 days / timeBase, 100 finney);
        MoreAssert.equal(total, v2 + v3, cBase, "total credit");
    }

    function testVaryingInterestRate() public {
        
        issuer.issueTokens(address(alpha), 100 finney);
        Assert.equal(creditToken.balanceOf(address(alpha)), 100 finney, "alpha credit t0");

        settings.setCreditInterestRate( // 5% per day
            10020349912970346474243981869599,
            10000000000000000000000000000000
        );
        
        time.setTimeOffset(1 days);
        MoreAssert.equal(creditToken.balanceOf(address(alpha)), 105 finney, cBase, "alpha credit t1");

        settings.setCreditInterestRate( // 9.5238% per day
            10037976837541235831695851518435,
            10000000000000000000000000000000
        );

        time.setTimeOffset(2 days);
        MoreAssert.equal(creditToken.balanceOf(address(alpha)), 115 finney, cBase, "alpha credit t2");

        settings.setCreditInterestRate( // 73.913% each two days
            10115955725553215120662198270526,
            10000000000000000000000000000000
        );

        time.setTimeOffset(4 days);
        MoreAssert.equal(creditToken.balanceOf(address(alpha)), 200 finney, cBase, "alpha credit t3");
    }
}