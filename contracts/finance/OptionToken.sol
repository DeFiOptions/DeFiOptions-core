pragma solidity >=0.6.0;

import "../../contracts/finance/CreditProvider.sol";
import "../../contracts/finance/OptionsExchange.sol";
import "../utils/ERC20.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";

contract OptionToken is ERC20 {

    using SafeMath for uint;

    CreditProvider private creditProvider;

    mapping(address => bool) private processed;

    string private code;
    address private issuer;
    address[] holders;

    constructor(
        string memory _code,
        address _issuer,
        address _creditProvider
    )
        public
    {
        code = _code;
        issuer = _issuer;
        creditProvider = CreditProvider(_creditProvider);
    }

    function getCode() external view returns (string memory) {

        return code;
    }

    function issue(address to, uint value) external {

        require(msg.sender == issuer, "issuance unallowed");
        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
    }

    function burn(uint value) external {

        require(balanceOf(msg.sender) >= value, "burn unallowed");
        removeBalance(msg.sender, value);
        _totalSupply = _totalSupply.sub(value);
        OptionsExchange(issuer).burnOptions(code, msg.sender, value);
    }

    function destroy() external {
        
        OptionsExchange exchange = OptionsExchange(issuer);
        exchange.liquidateCode(code);

        uint cpvTotal = creditProvider.balanceOf(address(this));
        uint cpv = cpvTotal;
        
        for (uint i = 0; i < holders.length && cpv > 0; i++) {
            if (!processed[holders[i]]) {

                uint bal = balanceOf(holders[i]);
                
                if (bal > 0) {
                    uint cpvVal = cpvTotal.mul(bal).div(_totalSupply);
                    creditProvider.transferBalance(holders[i], cpvVal);
                    cpv = cpv.sub(cpvVal);
                }
                
                processed[holders[i]] = true;
            }
        }
        
        if (cpv > 0) {
            creditProvider.transferBalance(msg.sender, cpv);
        }
        selfdestruct(msg.sender);
    }

    function addBalance(address owner, uint value) override internal {

        if (balanceOf(owner) == 0) {
            holders.push(address(owner));
        }
        balances[owner] = balanceOf(owner).add(value);
    }

    function emitTransfer(address from, address to, uint value) override internal {

        OptionsExchange(issuer).transferOwnership(code, from, to, value);
        emit Transfer(from, to, value);
    }
}