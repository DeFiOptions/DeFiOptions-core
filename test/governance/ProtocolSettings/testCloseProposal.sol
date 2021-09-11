pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "../../common/samples/ChangeInterestRateProposal.sol";
import "./Base.sol";

contract TestCloseProposal is Base {

    function testCloseProposalBeforeQuorum() public {
        
        ChangeInterestRateProposal p = createProposal(10 days);
        
        uint newInterestRate     = 10000000098765432;
        uint newInterestRateBase = 10000000000000001;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        alpha.registerProposal(p);
            
        (bool success,) = address(p).call(
            abi.encodePacked(
                p.close.selector
            )
        );
        
        Assert.isFalse(success, "close should fail");
    }

    function testCloseProposalThenTransferSmallAmountOfGovTokens() public {
        
        ChangeInterestRateProposal p = createProposal(10 days);
        
        uint newInterestRate     = 10000000012345678;
        uint newInterestRateBase = 10000000000000004;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        alpha.registerProposal(p);

        alpha.castVote(p, true);
        beta.castVote(p, false);
        gama.castVote(p, false);

        gama.transfer(address(alpha), 5 finney); // 0.5%

        (uint ir1, uint b1,) = settings.getDebtInterestRate();

        p.close();
        
        Assert.isTrue(p.getStatus() == Proposal.Status.REJECTED, "proposal REJECTED");

        (uint ir2, uint b2,) = settings.getDebtInterestRate();
        Assert.equal(ir1, ir2, "old interest rate");
        Assert.equal(b1, b2, "old interest rate base");
    }

    function testCloseProposalThenTransferLargerAmountOfGovTokens() public {
        
        ChangeInterestRateProposal p = createProposal(10 days);
        
        uint newInterestRate     = 10000000012345678;
        uint newInterestRateBase = 10000000000000004;
        p.setInterestRate(newInterestRate, newInterestRateBase);

        alpha.registerProposal(p);

        alpha.castVote(p, true);
        beta.castVote(p, false);
        gama.castVote(p, false);

        gama.transfer(address(alpha), 10 finney); // 1%

        (uint ir1, uint b1,) = settings.getDebtInterestRate();

        p.close();
        
        Assert.isTrue(p.getStatus() == Proposal.Status.APPROVED, "proposal APPROVED");

        (uint ir2, uint b2,) = settings.getDebtInterestRate();
        Assert.notEqual(ir1, ir2, "old interest rate");
        Assert.notEqual(b1, b2, "old interest rate base");
        Assert.equal(ir2, newInterestRate, "new interest rate");
        Assert.equal(b2, newInterestRateBase, "new interest rate base");
    }
}