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
    uint private _totalAccruedFees;

    event DepositTokens(address indexed owner, address indexed token, uint value);

    event WithdrawTokens(address indexed owner, address indexed token, uint value);

    event TransferBalance(address indexed from, address indexed to, uint value);

    event AccumulateDebt(address indexed to, uint value);

    event BurnDebt(address indexed from, uint value);

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        creditToken = CreditToken(deployer.getContractAddress("CreditToken"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));

        callers[address(settings)] = 1;
        callers[deployer.getContractAddress("CreditToken")] = 1;
        callers[deployer.getContractAddress("OptionsExchange")] = 1;
        callers[deployer.getContractAddress("LinearLiquidityPool")] = 1;

        ctAddr = address(creditToken);
    }

    function totalTokenStock() external view returns (uint v) {

        address[] memory tokens = settings.getAllowedTokens();
        for (uint i = 0; i < tokens.length; i++) {
            (uint r, uint b) = settings.getTokenRate(tokens[i]);
            uint value = ERC20(tokens[i]).balanceOf(address(this));
            v = v.add(value.mul(b).div(r));
        }
    }

    function totalAccruedFees() external view returns (uint) {

        return _totalAccruedFees;
    }

    function ensureCaller(address addr) public view {
        
        require(callers[addr] == 1, "unauthorized caller");
    }

    function issueCredit(address to, uint value) external {
        
        ensureCaller();

        require(msg.sender == address(settings));
        issueCreditTokens(to, value);
    }

    function balanceOf(address owner) public view returns (uint) {

        return balances[owner];
    }
    
    function addBalance(address to, address token, uint value) external {

        addBalance(to, token, value, false);
    }

    function transferBalance(address from, address to, uint value) public {

        ensureCaller();
        removeBalance(from, value);
        addBalance(to, value);
        emit TransferBalance(from, to, value);
    }
    
    function depositTokens(address to, address token, uint value) external {

        ERC20(token).transferFrom(msg.sender, address(this), value);
        addBalance(to, token, value, true);
        emit DepositTokens(to, token, value);
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

        debt = debts[addr];
        if (debt > 0) {
            debt = settings.applyDebtInterestRate(debt, debtsDate[addr]);
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

            transferBalance(from, to, value);

            if (credit > 0) {                
                applyDebtInterestRate(from);
                setDebt(from, debts[from].add(credit));
                addBalance(to, credit);
                emit AccumulateDebt(to, value);
            }
        }
    }
    
    function addBalance(address to, address token, uint value, bool trusted) private {

        if (value > 0) {

            if (!trusted) {
                ensureCaller();
            }
            
            (uint r, uint b) = settings.getTokenRate(token);
            require(r != 0 && token != ctAddr, "token not allowed");
            value = value.mul(b).div(r);
            addBalance(to, value);
            emit TransferBalance(address(0), to, value);
        }
    }
    
    function addBalance(address owner, uint value) private {

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
        
        uint d = applyDebtInterestRate(from);
        if (d > 0) {
            burnt = MoreMath.min(value, d);
            setDebt(from, d.sub(burnt));
            emit BurnDebt(from, value);
        }
    }

    function applyDebtInterestRate(address owner) private returns (uint debt) {

        uint d = debts[owner];
        if (d > 0) {

            debt = calcDebt(owner);

            if (debt > 0 && debt != d) {
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
                emit WithdrawTokens(to, tokens[i], v.mul(r).div(b));
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
        emit WithdrawTokens(to, ctAddr, value);
    }

    function ensureCaller() private view {
        
        ensureCaller(msg.sender);
    }
}