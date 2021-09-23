pragma solidity >=0.6.0;

import "../../../contracts/governance/GovToken.sol";
import "../../../contracts/governance/Proposal.sol";
import "../../../contracts/governance/ProposalsManager.sol";
import "../../../contracts/governance/ProposalWrapper.sol";

contract ShareHolder {
    
    GovToken govToken;
    ProposalsManager manager;
    address payable addr;
    
    constructor(address _govToken, address _mgr) public {
        addr = address(uint160(address(this)));
        govToken = GovToken(_govToken);
        manager = ProposalsManager(_mgr);
    }
    
    fallback() external payable { }
    receive() external payable { }

    function transfer(address to, uint amount) public {

        govToken.transfer(to, amount);
    }

    function delegateTo(address to) public {

        govToken.delegateTo(to);
    }
    
    function registerProposal(
        Proposal p,
        ProposalWrapper.Quorum quorum,
        uint expiresAt
    )
        public
        returns (uint id, ProposalWrapper wrapper)
    {    
        address w;
        (id, w) = manager.registerProposal(address(p), quorum, expiresAt);
        wrapper = ProposalWrapper(w);
    }

    function castVote(ProposalWrapper w, bool support) public {

        require(address(w) != address(0), "invalid 'ProposalWrapper' contract");
        w.castVote(support);
    }
}