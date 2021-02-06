pragma solidity >=0.6.0;

import "../../../contracts/governance/GovToken.sol";
import "../../../contracts/governance/Proposal.sol";

contract ShareHolder {
    
    GovToken govToken;
    address payable addr;
    
    constructor() public {
        addr = address(uint160(address(this)));
    }
    
    fallback() external payable { }
    receive() external payable { }

    function setGovToken(address _govToken) public {

        govToken = GovToken(_govToken);
    }

    function transfer(address to, uint amount) public {

        govToken.transfer(to, amount);
    }
    
    function registerProposal(Proposal p) public {
        
        govToken.registerProposal(address(p));
    }

    function castVote(Proposal p, bool support) public {

        p.castVote(support);
    }
}