pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../utils/ERC20.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";

contract OptionToken is ERC20 {

    using SafeMath for uint;

    string private code;
    address private issuer;
    address[] private holders;

    constructor(string memory _code, address _issuer) public {
        
        code = _code;
        issuer = _issuer;
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
        exchange.liquidateCode(code, uint(-1));

        uint valTotal = exchange.balanceOf(address(this));
        uint valRemaining = valTotal;
        
        for (uint i = 0; i < holders.length && valRemaining > 0; i++) {

            uint bal = balanceOf(holders[i]);
            
            if (bal > 0) {
                uint valTransfer = valTotal.mul(bal).div(_totalSupply);
                exchange.transferBalance(holders[i], valTransfer);
                valRemaining = valRemaining.sub(valTransfer);
                removeBalance(holders[i], bal);
            }
        }
        
        if (valRemaining > 0) {
            exchange.transferBalance(msg.sender, valRemaining);
        }
        selfdestruct(msg.sender);
    }

    function writtenVolume(address owner) external view returns (uint) {

        return OptionsExchange(issuer).writtenVolume(code, owner);
    }

    function addBalance(address owner, uint value) override internal {

        if (balanceOf(owner) == 0) {
            holders.push(owner);
        }
        balances[owner] = balanceOf(owner).add(value);
    }

    function emitTransfer(address from, address to, uint value) override internal {

        OptionsExchange(issuer).transferOwnership(code, from, to, value);
        emit Transfer(from, to, value);
    }
}