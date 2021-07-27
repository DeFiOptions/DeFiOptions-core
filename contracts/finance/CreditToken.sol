pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../governance/ProtocolSettings.sol";
import "../utils/ERC20.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/SafeMath.sol";
import "../utils/MoreMath.sol";
import "./CreditProvider.sol";

contract CreditToken is ManagedContract, ERC20 {

    using SafeMath for uint;

    struct WithdrawQueueItem {
        address addr;
        uint value;
        address nextAddr;
    }

    TimeProvider private time;
    ProtocolSettings private settings;
    CreditProvider private creditProvider;

    mapping(address => uint) private creditDates;
    mapping(address => WithdrawQueueItem) private queue;

    string private constant _name = "Credit Token";
    string private constant _symbol = "CREDTK";

    address private issuer;
    address private headAddr;
    address private tailAddr;

    constructor() ERC20(_name) public {
        
    }

    function initialize(Deployer deployer) override internal {

        DOMAIN_SEPARATOR = ERC20(getImplementation()).DOMAIN_SEPARATOR();
        
        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        issuer = deployer.getContractAddress("CreditIssuer");
    }

    function name() override external view returns (string memory) {
        return _name;
    }

    function symbol() override external view returns (string memory) {
        return _symbol;
    }

    function issue(address to, uint value) public {

        require(msg.sender == issuer, "issuance unallowed");
        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        emitTransfer(address(0), to, value);
    }

    function balanceOf(address owner) override public view returns (uint bal) {

        bal = 0;
        if (balances[owner] > 0) {
            bal = settings.applyCreditInterestRate(balances[owner], creditDates[owner]);
        }
    }

    function requestWithdraw(uint value) public {

        uint sent;
        if (headAddr == address(0)) {
            (sent,) = withdrawTokens(msg.sender, value);
        }
        if (sent < value) {
            enqueueWithdraw(msg.sender, value.sub(sent));
        }
    }

    function processWithdraws(uint limit) public {
        
        while (headAddr != address(0) && (limit-- > 0)) {
            (uint sent, bool dequeue) = withdrawTokens(
                queue[headAddr].addr,
                queue[headAddr].value
            );
            if (dequeue) {
                dequeueWithdraw();
            } else {
                queue[headAddr].value = queue[headAddr].value.sub(sent);
                break;
            }
        }
    }

    function addBalance(address owner, uint value) override internal {

        updateBalance(owner);
        balances[owner] = balances[owner].add(value);
    }

    function removeBalance(address owner, uint value) override internal {

        updateBalance(owner);
        balances[owner] = balances[owner].sub(value);
    }

    function updateBalance(address owner) private {

        uint nb = balanceOf(owner);
        _totalSupply = _totalSupply.add(nb).sub(balances[owner]);
        balances[owner] = nb;
        creditDates[owner] = time.getNow();
    }

    function enqueueWithdraw(address owner, uint value) private {

        if (queue[owner].addr == owner) {
            
            require(queue[owner].value > value, "invalid value");
            queue[owner].value = value;

        } else {

            queue[owner] = WithdrawQueueItem(owner, value, address(0));
            if (headAddr == address(0)) {
                headAddr = owner;
            } else {
                queue[tailAddr].nextAddr = owner;
            }
            tailAddr = owner;

        }
    }

    function dequeueWithdraw() private {

        address aux = headAddr;
        headAddr = queue[headAddr].nextAddr;
        if (headAddr == address(0)) {
            tailAddr = address(0);
        }
        delete queue[aux];
    }

    function withdrawTokens(address owner, uint value) private returns(uint sent, bool dequeue) {

        if (value > 0) {

            value = MoreMath.min(balanceOf(owner), value);
            uint b = creditProvider.totalTokenStock();

            if (b >= value) {
                sent = value;
                dequeue = true;
            } else {
                sent = b;
            }

            if (sent > 0) {
                removeBalance(owner, sent);
                creditProvider.grantTokens(owner, sent);
            }
        }
    }
}