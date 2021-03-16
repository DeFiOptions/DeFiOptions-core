pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../../contracts/finance/RedeemableToken.sol";
import "../utils/ERC20.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";

contract OptionToken is RedeemableToken {

    using SafeMath for uint;

    string private _symbol;

    constructor(string memory _sb, address _issuer) public {
        
        _symbol = _sb;
        exchange = OptionsExchange(_issuer);
    }

    function name() override external view returns (string memory) {
        return string(abi.encodePacked("Option Redeemable Token: ", _symbol));
    }

    function symbol() override external view returns (string memory) {

        return _symbol;
    }

    function decimals() override external view returns (uint8) {
        return 18;
    }

    function issue(address to, uint value) external {

        require(msg.sender == address(exchange), "issuance unallowed");
        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        emitTransfer(address(0), to, value);
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