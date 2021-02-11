pragma solidity >=0.6.0;

import "../interfaces/TimeProvider.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "./GovToken.sol";

abstract contract Proposal {

    using SafeMath for uint;

    enum Quorum { SIMPLE_MAJORITY, TWO_THIRDS }

    enum Status { PENDING, OPEN, APPROVED, REJECTED }

    TimeProvider private time;
    GovToken private govToken;

    mapping(address => int) private votes;
    
    uint private id;
    uint private yea;
    uint private nay;
    Quorum private quorum;
    Status private status;
    uint private expiresAt;
    bool private closed;

    constructor(
        address _time,
        address _govToken,
        Quorum _quorum,
        uint _expiresAt
    )
        public
    {
        time = TimeProvider(_time);
        govToken = GovToken(_govToken);
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

    function isClosed() public view returns (bool) {

        return closed;
    }

    function open(uint _id) public {

        require(msg.sender == address(govToken));
        require(status == Status.PENDING);
        id = _id;
        status = Status.OPEN;
    }

    function castVote(bool support) public {
        
        ensureIsActive();
        require(votes[msg.sender] == 0);
        
        uint balance = govToken.balanceOf(msg.sender);
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

        uint total = govToken.totalSupply();

        uint v;
        if (quorum == Proposal.Quorum.SIMPLE_MAJORITY) {
            v = total.div(2);
        } else if (quorum == Proposal.Quorum.TWO_THIRDS) {
            v = total.mul(2).div(3);
        } else {
            revert();
        }

        if (yea > v) {
            status = Status.APPROVED;
            execute();
        } else if (nay >= v) {
            status = Status.REJECTED;
        } else {
            revert("quorum not reached");
        }

        closed = true;
    }

    function execute() public virtual;

    function ensureIsActive() private view {

        require(!closed);
        require(status == Status.OPEN);
        require(expiresAt > time.getNow());
    }

    function update(address voter, int diff) private {

        if (votes[voter] != 0) {
            ensureIsActive();
            require(msg.sender == address(govToken));

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