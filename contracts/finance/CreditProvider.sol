pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../governance/ProtocolSettings.sol";
import "../utils/ERC20.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./CreditToken.sol";

contract CreditProvider is ManagedContract {

    using SafeMath for uint;
    using SignedSafeMath for int;
    
    TimeProvider private time;
    ProtocolSettings private settings;
    CreditToken private creditToken;

    mapping(address => uint) private balances;
    mapping(address => uint) private debts;
    mapping(address => uint) private debtsDate;
    mapping(address => uint) private callers;

    address private ctAddr;
    uint private _totalTokenStock;
    uint private _totalAccruedFees;

    constructor(address deployer) public {

        Deployer(deployer).setContractAddress("CreditProvider");
        Deployer(deployer).addAlias("CreditIssuer", "CreditProvider");
    }

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        creditToken = CreditToken(deployer.getContractAddress("CreditToken"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));

        callers[address(settings)] = 1;
        callers[deployer.getContractAddress("CreditToken")] = 1;
        callers[deployer.getContractAddress("OptionsExchange")] = 1;

        ctAddr = address(creditToken);
    }

    function totalTokenStock() external view returns (uint) {

        return _totalTokenStock;
    }

    function totalAccruedFees() external view returns (uint) {

        return _totalAccruedFees;
    }

    function issueCredit(address to, uint value) external {
        
        ensureCaller();

        require(msg.sender == address(settings));
        issueCreditTokens(to, value);
    }

    function balanceOf(address owner) public view returns (uint) {

        return balances[owner];
    }

    function transferBalance(address to, uint value) public {
        
        transferBalanceFrom(msg.sender, to, value);
    }
    
    function depositTokens(address to, address token, uint value) external {

        if (value > 0) {
            
            (uint r, uint b) = settings.getTokenRate(token);
            require(r != 0 && token != ctAddr, "token not allowed");
            ERC20(token).transferFrom(msg.sender, address(this), value);
            value = value.mul(b).div(r);
            addBalance(to, value);
            _totalTokenStock = _totalTokenStock.add(value);
        }
    }

    function withdrawTokens(address owner, uint value) external {
        
        ensureCaller();
        removeBalance(owner, value);
        burnDebtAndTransferTokens(owner, value);
    }

    function grantTokens(address to, uint value) external {
        
        ensureCaller();
        burnDebtAndTransferTokens(to, value);
    }

    function calcDebt(address addr) public view returns (uint debt) {

        debt = 0;
        if (debts[addr] > 0) {
            debt = settings.applyDebtInterestRate(debts[addr], debtsDate[addr]);
        }
    }

    function processPayment(address from, address to, uint value) external {
        
        ensureCaller();

        require(from != to);

        if (value > 0) {

            (uint v, uint b) = settings.getProcessingFee();
            if (v > 0) {
                uint fee = MoreMath.min(value.mul(v).div(b), balanceOf(from));
                value = value.sub(fee);
                _totalAccruedFees = _totalAccruedFees.add(fee);
            }

            uint credit;
            if (balanceOf(from) < value) {
                credit = value.sub(balanceOf(from));
                value = balanceOf(from);
            }

            transferBalanceFrom(from, to, value);

            if (credit > 0) {                
                applyDebtInterestRate(from);
                setDebt(from, debts[from].add(credit));
                addBalance(to, credit);
            }
        }
    }

    function transferBalanceFrom(address from, address to, uint value) private {
        
        removeBalance(from, value);
        addBalance(to, value);
    }
    
    function addBalance(address owner, uint value) public {

        if (value > 0) {

            uint burnt = burnDebt(owner, value);
            uint v = value.sub(burnt);
            balances[owner] = balances[owner].add(v);
        }
    }
    
    function removeBalance(address owner, uint value) private {
        
        require(balances[owner] >= value, "insufficient balance");
        balances[owner] = balances[owner].sub(value);
    }

    function burnDebtAndTransferTokens(address to, uint value) private {

        if (debts[to] > 0) {
            uint burnt = burnDebt(to, value);
            value = value.sub(burnt);
        }

        transferTokens(to, value);
    }

    function burnDebt(address from, uint value) private returns (uint burnt) {
        
        applyDebtInterestRate(from);
        burnt = MoreMath.min(value, debts[from]);
        setDebt(from, debts[from].sub(burnt));
    }

    function applyDebtInterestRate(address owner) private {

        if (debts[owner] > 0) {

            uint debt = calcDebt(owner);

            if (debt > 0 && debt != debts[owner]) {
                setDebt(owner, debt);
            }
        }
    }

    function setDebt(address owner, uint value)  private {
        
        debts[owner] = value;
        debtsDate[owner] = time.getNow();
    }

    function transferTokens(address to, uint value) private returns (uint) {
        
        require(to != address(this) && to != ctAddr, "invalid token transfer address");

        address[] memory tokens = settings.getAllowedTokens();
        for (uint i = 0; i < tokens.length && value > 0; i++) {
            ERC20 t = ERC20(tokens[i]);
            (uint r, uint b) = settings.getTokenRate(tokens[i]);
            if (b != 0) {
                uint v = MoreMath.min(value, t.balanceOf(address(this)).mul(b).div(r));
                t.transfer(to, v.mul(r).div(b));
                _totalTokenStock = _totalTokenStock.sub(v);
                value = value.sub(v);
            }
        }
        
        if (value > 0) {
            issueCreditTokens(to, value);
        }
    }

    function issueCreditTokens(address to, uint value) private {
        
        (uint r, uint b) = settings.getTokenRate(ctAddr);
        if (b != 0) {
            value = value.mul(r).div(b);
        }
        creditToken.issue(to, value);
    }

    function ensureCaller()  private view {
        
        require(callers[msg.sender] == 1, "unauthorized caller");
    }
}