pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../../contracts/finance/RedeemableToken.sol";
import "../utils/ERC20.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";

contract OptionToken is RedeemableToken {

    using SafeMath for uint;

    string private constant _prefix = "Option Redeemable Token: ";
    string private _symbol;

    constructor(string memory _sb, address _issuer)
        ERC20(string(abi.encodePacked(_prefix, _symbol)))
        public
    {    
        _symbol = _sb;
        exchange = OptionsExchange(_issuer);
    }

    function name() override external view returns (string memory) {
        return string(abi.encodePacked(_prefix, _symbol));
    }

    function symbol() override external view returns (string memory) {

        return _symbol;
    }

    function issue(address to, uint value) external {

        require(msg.sender == address(exchange), "issuance unallowed");
        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        emit Transfer(address(0), to, value);
    }

    function burn(uint value) external {

        require(balanceOf(msg.sender) >= value, "burn unallowed");
        removeBalance(msg.sender, value);
        _totalSupply = _totalSupply.sub(value);
        exchange.burnOptions(_symbol, msg.sender, value);
    }

    function writtenVolume(address owner) external view returns (uint) {

        return exchange.writtenVolume(_symbol, owner);
    }

    function redeemAllowed() override public returns (bool) {
        
        exchange.liquidateSymbol(_symbol, uint(-1));
        return true;
    }

    function addBalance(address owner, uint value) override internal {

        if (balanceOf(owner) == 0) {
            holders.push(owner);
        }
        balances[owner] = balanceOf(owner).add(value);
    }

    function emitTransfer(address from, address to, uint value) override internal {

        exchange.transferOwnership(_symbol, from, to, value);
        emit Transfer(from, to, value);
    }
}