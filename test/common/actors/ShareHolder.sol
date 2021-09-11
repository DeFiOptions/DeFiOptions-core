pragma solidity >=0.6.0;

import "../../../contracts/governance/GovToken.sol";
import "../../../contracts/governance/Proposal.sol";

contract ShareHolder {
    
    GovToken govToken;
    address payable addr;
    
    constructor(address _govToken) public {
        addr = address(uint160(address(this)));
        govToken = GovToken(_govToken);
    }
    
    fallback() external payable { }
    receive() external payable { }

    function transfer(address to, uint amount) public {

        govToken.transfer(to, amount);
    }

    function delegateTo(address to) public {

        govToken.delegateTo(to);
    }

    function delegateTo(address to, bool suppresHotVoting) public {

        govToken.delegateTo(to, suppresHotVoting);
    }
    
    function registerProposal(Proposal p) public {
        
        govToken.registerProposal(address(p));
    }

    function castVote(Proposal p, bool support) public {

        p.castVote(support);
    }
}