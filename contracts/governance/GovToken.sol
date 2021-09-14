pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../utils/ERC20.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";
import "./ProposalWrapper.sol";
import "./ProtocolSettings.sol";

contract GovToken is ManagedContract, ERC20 {

    using SafeMath for uint;

    TimeProvider private time;
    ProtocolSettings private settings;

    mapping(address => uint) private proposingDate;
    mapping(address => address) private wrapper;
    
    mapping(address => uint) private transferBlock;

    mapping(address => address) private delegation;
    mapping(address => uint) private delegated;

    address public childChainManagerProxy;

    string private constant _name = "Governance Token";
    string private constant _symbol = "GOVTK";
    
    uint private serial;
    address[] private proposals;

    event DelegateTo(
        address indexed owner,
        address indexed oldDelegate,
        address indexed newDelegate,
        uint bal
    );

    event RegisterProposal(
        address indexed wrapper,
        address indexed addr,
        ProposalWrapper.Quorum quorum,
        uint expiresAt
    );

    constructor(address _childChainManagerProxy) ERC20(_name) public {

        childChainManagerProxy = _childChainManagerProxy;
    }
    
    function initialize(Deployer deployer) override internal {

        DOMAIN_SEPARATOR = ERC20(getImplementation()).DOMAIN_SEPARATOR();
        childChainManagerProxy = GovToken(getImplementation()).childChainManagerProxy();

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        serial = 1;
    }

    function name() override external view returns (string memory) {
        return _name;
    }

    function symbol() override external view returns (string memory) {
        return _symbol;
    }
    
    function setChildChainManager(address _childChainManagerProxy) external {

        require(childChainManagerProxy == address(0), "childChainManagerProxy already set");
        childChainManagerProxy = _childChainManagerProxy;
    }

    function deposit(
        address user,
        bytes calldata depositData
    )
        external
    {
        require(msg.sender == childChainManagerProxy, "You're not allowed to deposit");
        uint256 amount = abi.decode(depositData, (uint256));
        _totalSupply = _totalSupply.add(amount);
        addBalance(user, amount);
        emitTransfer(address(0), user, amount);
    }

    function withdraw(uint256 amount) external {

        removeBalance(msg.sender, amount);
        _totalSupply = _totalSupply.sub(amount);
        emitTransfer(msg.sender, address(0), amount);
    }

    function delegateBalanceOf(address delegate) external view returns (uint) {

        return delegated[delegate];
    }

    function delegateTo(address newDelegate) external {

        delegateTo(newDelegate, false);
    }

    function delegateTo(address newDelegate, bool supressHotVoting) public {

        address oldDelegate = delegation[msg.sender];

        require(newDelegate != address(0), "invalid delegate address");

        require(
            (settings.allowHotVoting() && !supressHotVoting) || // for unit testing purposes only
            transferBlock[tx.origin] != block.number,
            "delegation not allowed"
        );

        uint bal = balanceOf(msg.sender);

        if (oldDelegate != address(0)) {
            delegated[oldDelegate] = delegated[oldDelegate].sub(bal);
        }

        delegated[newDelegate] = delegated[newDelegate].add(bal);
        delegation[msg.sender] = newDelegate;

        emit DelegateTo(msg.sender, oldDelegate, newDelegate, bal);
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
        require(calcShare(msg.sender, b) >= v, "insufficient share");

        ProposalWrapper w = new ProposalWrapper(
            addr,
            address(time), 
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

    function calcShare(address owner, uint base) private view returns (uint) {

        return delegated[owner].mul(base).div(settings.getCirculatingSupply());
    }

    function emitTransfer(address from, address to, uint value) override internal {

        transferBlock[tx.origin] = block.number;

        address fromDelegate = delegation[from];
        address toDelegate = delegation[to];

        for (uint i = 0; i < proposals.length; i++) {
            ProposalWrapper w = ProposalWrapper(proposals[i]);
            if (w.isClosed()) {
                Arrays.removeAtIndex(proposals, i);
                i--;
            } else {
                w.update(fromDelegate, toDelegate, value);
            }
        }

        if (fromDelegate != address(0)) {
            delegated[fromDelegate] = delegated[fromDelegate].sub(value);
        }

        if (toDelegate != address(0)) {
            delegated[toDelegate] = delegated[toDelegate].add(value);
        }

        emit Transfer(from, to, value);
    }
}