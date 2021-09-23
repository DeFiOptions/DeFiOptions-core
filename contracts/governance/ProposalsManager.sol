pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";
import "./ProposalWrapper.sol";
import "./ProtocolSettings.sol";
import "./GovToken.sol";

contract ProposalsManager is ManagedContract {

    using SafeMath for uint;

    TimeProvider private time;
    ProtocolSettings private settings;
    GovToken private govToken;

    mapping(address => uint) private proposingDate;
    mapping(address => address) private wrapper;
    
    uint private serial;
    address[] private proposals;

    event RegisterProposal(
        address indexed wrapper,
        address indexed addr,
        ProposalWrapper.Quorum quorum,
        uint expiresAt
    );
    
    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        govToken = GovToken(deployer.getContractAddress("GovToken"));
        serial = 1;
    }

    function registerProposal(
        address addr,
        ProposalWrapper.Quorum quorum,
        uint expiresAt
    )
        public
        returns (uint id, address wp)
    {    
        require(
            proposingDate[msg.sender] == 0 || time.getNow().sub(proposingDate[msg.sender]) > 1 days,
            "minimum interval between proposals not met"
        );
        
        (uint v, uint b) = settings.getMinShareForProposal();
        require(govToken.calcShare(msg.sender, b) >= v, "insufficient share");

        ProposalWrapper w = new ProposalWrapper(
            addr,
            address(time), 
            address(govToken),
            address(this),
            address(settings),
            quorum,
            expiresAt
        );

        proposingDate[msg.sender] = time.getNow();
        id = serial++;
        w.open(id);
        wp = address(w);
        proposals.push(wp);
        wrapper[addr] = wp;

        emit RegisterProposal(wp, addr, quorum, expiresAt);
    }

    function isRegisteredProposal(address addr) public view returns (bool) {
        
        address wp = wrapper[addr];
        if (wp == address(0)) {
            return false;
        }
        
        ProposalWrapper w = ProposalWrapper(wp);
        return w.implementation() == addr;
    }

    function resolve(address addr) public view returns (address) {

        return wrapper[addr];
    }

    function update(address from, address to, uint value) public {

        for (uint i = 0; i < proposals.length; i++) {
            ProposalWrapper w = ProposalWrapper(proposals[i]);
            if (!w.isActive()) {
                Arrays.removeAtIndex(proposals, i);
                i--;
            } else {
                w.update(from, to, value);
            }
        }
    }
}