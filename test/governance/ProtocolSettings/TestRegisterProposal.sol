pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestRegisterProposal is Base {

    function testRegisterProposalMeetingMinimumShares() public {
        
        Proposal p = createProposal(10 days);

        Assert.isFalse(
            govToken.isRegisteredProposal(address(p)), "proposal not registered"
        );
        
        alpha.registerProposal(p);

        Assert.isTrue(
            govToken.isRegisteredProposal(address(p)), "proposal registered"
        );

        Assert.isTrue(p.getId() > 0, "p ID");
        Assert.isTrue(p.getStatus() == Proposal.Status.OPEN, "p OPEN");
    }

    function testRegisterProposalWithoutMinimumShares() public {
        
        Proposal p = createProposal(10 days);

        alpha.transfer(address(beta), govToken.balanceOf(address(alpha)) - 5 finney); // 0.5% left
        
        (bool success,) = address(alpha).call(
            abi.encodePacked(
                alpha.registerProposal.selector,
                abi.encode(p)
            )
        );
        
        Assert.isFalse(success, "registerProposal should fail");
    }
}