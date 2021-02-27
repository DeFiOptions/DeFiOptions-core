pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../utils/ERC20.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";

contract OptionToken is ERC20 {

    using SafeMath for uint;

    string private _symbol;
    address private issuer;
    address[] private holders;

    constructor(string memory _sb, address _issuer) public {
        
        _symbol = _sb;
        issuer = _issuer;
    }

    function symbol() external view returns (string memory) {

        return _symbol;
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
        OptionsExchange(issuer).burnOptions(_symbol, msg.sender, value);
    }

    function writtenVolume(address owner) external view returns (uint) {

        return OptionsExchange(issuer).writtenVolume(_symbol, owner);
    }

    function destroy() external {
        
        OptionsExchange exchange = OptionsExchange(issuer);
        exchange.liquidateSymbol(_symbol, uint(-1));

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

    function addBalance(address owner, uint value) override internal {

        if (balanceOf(owner) == 0) {
            holders.push(owner);
        }
        balances[owner] = balanceOf(owner).add(value);
    }

    function emitTransfer(address from, address to, uint value) override internal {

        OptionsExchange(issuer).transferOwnership(_symbol, from, to, value);
        emit Transfer(from, to, value);
    }
}