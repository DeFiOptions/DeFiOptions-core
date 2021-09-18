pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestTransferBalance is Base {

    function testTransferBalanceWithinLimits() public {
        
        depositTokens(address(settings), 200e18);
        depositTokens(address(this), 800e18);

        TransferBalanceProposal p = new TransferBalanceProposal();
        p.setAmount(80e18);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, true);
        gama.castVote(w, true);

        (bool success,) = address(w).call(
            abi.encodePacked(
                w.close.selector
            )
        );

        Assert.isTrue(success, "close should succed");
        
        Assert.equal(120e18, exchange.balanceOf(address(settings)), "settings balance");
        Assert.equal(800e18, exchange.balanceOf(address(this)), "self balance");
        Assert.equal(80e18, exchange.balanceOf(address(p)), "proposal balance");
    }

    function testTransferBalanceAboveLimits() public {
        
        depositTokens(address(settings), 200e18);
        depositTokens(address(this), 600e18);

        TransferBalanceProposal p = new TransferBalanceProposal();
        p.setAmount(201e18);

        (,ProposalWrapper w) = alpha.registerProposal(p, SIMPLE_MAJORITY, now + 10 days);

        alpha.castVote(w, true);
        beta.castVote(w, true);
        gama.castVote(w, true);

        (bool success,) = address(w).call(
            abi.encodePacked(
                w.close.selector
            )
        );

        Assert.isFalse(success, "close should fail");
    }
}