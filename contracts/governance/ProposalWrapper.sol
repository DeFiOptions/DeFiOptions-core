pragma solidity >=0.6.0;

import "../interfaces/TimeProvider.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "./GovToken.sol";
import "./Proposal.sol";
import "./ProposalsManager.sol";
import "./ProtocolSettings.sol";

contract ProposalWrapper {

    using SafeMath for uint;

    enum Quorum { SIMPLE_MAJORITY, TWO_THIRDS }

    enum Status { PENDING, OPEN, APPROVED, REJECTED }

    TimeProvider private time;
    GovToken private govToken;
    ProposalsManager private manager;
    ProtocolSettings private settings;

    mapping(address => int) private votes;

    address public implementation;
    
    uint private id;
    uint private yea;
    uint private nay;
    Quorum private quorum;
    Status private status;
    uint private expiresAt;
    bool private closed;

    constructor(
        address _implementation,
        address _time,
        address _govToken,
        address _manager,
        address _settings,
        Quorum _quorum,
        uint _expiresAt
    )
        public
    {
        implementation = _implementation;
        time = TimeProvider(_time);
        govToken = GovToken(_govToken);
        manager = ProposalsManager(_manager);
        settings = ProtocolSettings(_settings);
        quorum = _quorum;
        status = Status.PENDING;
        expiresAt = _expiresAt;
        closed = false;
    }

    function getId() public view returns (uint) {

        return id;
    }

    function getQuorum() public view returns (Quorum) {

        return quorum;
    }

    function getStatus() public view returns (Status) {

        return status;
    }

    function isExecutionAllowed() public view returns (bool) {

        return status == Status.APPROVED && !closed;
    }

    function isActive() public view returns (bool) {

        return
            !closed &&
            status == Status.OPEN &&
            expiresAt > time.getNow();
    }

    function isClosed() public view returns (bool) {

        return closed;
    }

    function open(uint _id) public {

        require(msg.sender == address(manager), "invalid sender");
        require(status == Status.PENDING, "invalid status");
        id = _id;
        status = Status.OPEN;
    }

    function castVote(bool support) public {
        
        ensureIsActive();
        require(votes[msg.sender] == 0, "already voted");
        
        uint balance = govToken.delegateBalanceOf(msg.sender);
        require(balance > 0);

        if (support) {
            votes[msg.sender] = int(balance);
            yea = yea.add(balance);
        } else {
            votes[msg.sender] = int(-balance);
            nay = nay.add(balance);
        }
    }

    function update(address from, address to, uint value) public {

        update(from, -int(value));
        update(to, int(value));
    }

    function close() public {

        ensureIsActive();

        govToken.enforceHotVotingSetting();

        uint total = settings.getCirculatingSupply();

        uint v;
        if (quorum == ProposalWrapper.Quorum.SIMPLE_MAJORITY) {
            v = total.div(2);
        } else if (quorum == ProposalWrapper.Quorum.TWO_THIRDS) {
            v = total.mul(2).div(3);
        } else {
            revert("quorum not set");
        }

        if (yea > v) {
            status = Status.APPROVED;
            Proposal(implementation).execute(settings);
        } else if (nay >= v) {
            status = Status.REJECTED;
        } else {
            revert("quorum not reached");
        }

        closed = true;
    }

    function ensureIsActive() private view {

        require(isActive(), "ProposalWrapper not active");
    }

    function update(address voter, int diff) private {
        
        if (votes[voter] != 0 && isActive()) {
            require(msg.sender == address(manager), "invalid sender");

            uint _diff = MoreMath.abs(diff);
            uint oldBalance = MoreMath.abs(votes[voter]);
            uint newBalance = diff > 0 ? oldBalance.add(_diff) : oldBalance.sub(_diff);

            if (votes[voter] > 0) {
                yea = yea.add(newBalance).sub(oldBalance);
            } else {
                nay = nay.add(newBalance).sub(oldBalance);
            }
        }
    }
}