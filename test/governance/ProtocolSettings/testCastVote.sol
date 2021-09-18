pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestCastVote is Base {

    function testCastVoteForApproval() public {
        
        ChangeInterestRateProposal p = new ChangeInterestRateProposal();
        
        uint newInterestRate     = 10000000098397720;
        uint newInterestRateBase = 10000000000000002;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, true);
        gama.castVote(w, false);

        (uint ir1, uint b1,) = settings.getDebtInterestRate();

        w.close();
        
        Assert.isTrue(w.getStatus() == ProposalWrapper.Status.APPROVED, "proposal APPROVED");

        (uint ir2, uint b2,) = settings.getDebtInterestRate();
        Assert.notEqual(ir1, ir2, "old interest rate");
        Assert.notEqual(b1, b2, "old interest rate base");
        Assert.equal(ir2, newInterestRate, "new interest rate");
        Assert.equal(b2, newInterestRateBase, "new interest rate base");
    }

    function testCastVoteForRejection() public {
        
        ChangeInterestRateProposal p = new ChangeInterestRateProposal();
        
        uint newInterestRate     = 10000000088884444;
        uint newInterestRateBase = 10000000000000003;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, false);
        gama.castVote(w, false);

        (uint ir1, uint b1,) = settings.getDebtInterestRate();

        w.close();
        
        Assert.isTrue(w.getStatus() == ProposalWrapper.Status.REJECTED, "proposal REJECTED");

        (uint ir2, uint b2,) = settings.getDebtInterestRate();
        Assert.equal(ir1, ir2, "old interest rate");
        Assert.equal(b1, b2, "old interest rate base");
        Assert.notEqual(ir2, newInterestRate, "new interest rate");
        Assert.notEqual(b2, newInterestRateBase, "new interest rate base");
    }
}