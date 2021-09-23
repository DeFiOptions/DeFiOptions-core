pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestCloseProposal is Base {

    function testCloseProposalBeforeQuorum() public {
        
        ChangeInterestRateProposal p = new ChangeInterestRateProposal();
        
        uint newInterestRate     = 10000000098765432;
        uint newInterestRateBase = 10000000000000001;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);
            
        (bool success,) = address(w).call(
            abi.encodePacked(
                w.close.selector
            )
        );
        
        Assert.isFalse(success, "close should fail");
    }

    function testCloseProposalThenTransferSmallAmountOfGovTokens() public {
        
        ChangeInterestRateProposal p = new ChangeInterestRateProposal();
        
        uint newInterestRate     = 10000000012345678;
        uint newInterestRateBase = 10000000000000004;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, false);
        gama.castVote(w, false);

        gama.transfer(address(alpha), 5 finney); // 0.5%

        (uint ir1, uint b1,) = settings.getDebtInterestRate();

        w.close();
        
        Assert.isTrue(w.getStatus() == ProposalWrapper.Status.REJECTED, "proposal REJECTED");

        (uint ir2, uint b2,) = settings.getDebtInterestRate();
        Assert.equal(ir1, ir2, "old interest rate");
        Assert.equal(b1, b2, "old interest rate base");
    }

    function testCloseProposalThenTransferLargerAmountOfGovTokens() public {
        
        ChangeInterestRateProposal p = new ChangeInterestRateProposal();
        
        uint newInterestRate     = 10000000012345678;
        uint newInterestRateBase = 10000000000000004;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, false);
        gama.castVote(w, false);

        gama.transfer(address(alpha), 10 finney); // 1%

        (uint ir1, uint b1,) = settings.getDebtInterestRate();

        w.close();
        
        Assert.isTrue(w.getStatus() == ProposalWrapper.Status.APPROVED, "proposal APPROVED");

        (uint ir2, uint b2,) = settings.getDebtInterestRate();
        Assert.notEqual(ir1, ir2, "old interest rate");
        Assert.notEqual(b1, b2, "old interest rate base");
        Assert.equal(ir2, newInterestRate, "new interest rate");
        Assert.equal(b2, newInterestRateBase, "new interest rate base");
    }

    function testCloseProposalWhenHotVotingIsNotAllowed() public {
        
        ChangeInterestRateProposal p = new ChangeInterestRateProposal();
        
        uint newInterestRate     = 10000000012345678;
        uint newInterestRateBase = 10000000000000004;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, false);
        gama.castVote(w, false);

        gama.transfer(address(alpha), 10 finney); // 1%

        settings.suppressHotVoting();

        (bool success,) = address(w).call(
            abi.encodePacked(
                w.close.selector
            )
        );
        
        Assert.isFalse(success, "close should fail");
    }
}