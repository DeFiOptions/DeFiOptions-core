pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../utils/ERC20.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";
import "./Proposal.sol";
import "./ProtocolSettings.sol";

contract GovToken is ManagedContract, ERC20 {

    using SafeMath for uint;

    TimeProvider private time;
    ProtocolSettings private settings;

    mapping(uint => Proposal) private proposalsMap;
    mapping(address => uint) private proposingDate;

    uint private serial;
    uint[] private proposals;

    constructor(address deployer) public {

        Deployer(deployer).setContractAddress("GovToken");
    }
    
    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        serial = 1;
    }

    function setInitialSupply(address owner, uint supply) public {
        
        require(_totalSupply == 0, "initial supply already set");
        _totalSupply = supply;
        balances[owner] = supply;
    }

    function registerProposal(address addr) public returns (uint id) {
        
        require(
            proposingDate[addr] == 0 || time.getNow() - proposingDate[addr] > 1 days,
            "minimum interval between proposals not met"
        );

        Proposal p = Proposal(addr);
        (uint v, uint b) = settings.getMinShareForProposal();
        require(calcShare(msg.sender, b) >= v);

        id = serial++;
        p.open(id);
        proposalsMap[id] = p;
        proposingDate[addr] = time.getNow();
        proposals.push(id);
    }

    function isRegisteredProposal(address addr) public view returns (bool) {
        
        Proposal p = Proposal(addr);
        return address(proposalsMap[p.getId()]) == addr;
    }

    function calcShare(address owner, uint base) private view returns (uint) {

        return balanceOf(owner).mul(base).div(_totalSupply);
    }

    function emitTransfer(address from, address to, uint value) override internal {

        for (uint i = 0; i < proposals.length; i++) {
            uint id = proposals[i];
            Proposal p = proposalsMap[id];
            if (p.isClosed()) {
                Arrays.removeAtIndex(proposals, i);
                i--;
            } else {
                p.update(from, to, value);
            }
        }

        emit Transfer(from, to, value);
    }
}