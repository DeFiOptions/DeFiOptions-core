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

    address public childChainManagerProxy;

    string private constant _name = "Governance Token";
    string private constant _symbol = "GOVTK";

    uint private serial;
    uint[] private proposals;

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

    function registerProposal(address addr) public returns (uint id) {
        
        require(
            proposingDate[addr] == 0 || time.getNow().sub(proposingDate[addr]) > 1 days,
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

        return balanceOf(owner).mul(base).div(settings.getCirculatingSupply());
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