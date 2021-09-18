pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestRegisterProposal is Base {

    function testRegisterProposalMeetingMinimumShares() public {
        
        Proposal p = new ChangeInterestRateProposal();

        Assert.isFalse(
            manager.isRegisteredProposal(address(p)), "proposal not registered"
        );
        
        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        Assert.isTrue(
            manager.isRegisteredProposal(address(p)), "proposal registered"
        );

        Assert.isTrue(w.getId() > 0, "p ID");
        Assert.isTrue(w.getStatus() == ProposalWrapper.Status.OPEN, "p OPEN");
    }

    function testRegisterProposalWithoutMinimumShares() public {
        
        Proposal p = new ChangeInterestRateProposal();

        alpha.transfer(address(beta), govToken.balanceOf(address(alpha)) - 5 finney); // 0.5% left
        
        (bool success,) = address(alpha).call(
            abi.encodePacked(
                alpha.registerProposal.selector,
                abi.encode(p, SIMPLE_MAJORITY, now + 10 days)
            )
        );
        
        Assert.isFalse(success, "registerProposal should fail");
    }
}