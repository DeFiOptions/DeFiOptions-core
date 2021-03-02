pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../../contracts/utils/ERC20.sol";
import "../../contracts/utils/SafeMath.sol";

abstract contract RedeemableToken is ERC20 {

    using SafeMath for uint;

    OptionsExchange internal exchange;

    address[] internal holders;

    function redeemAllowed() virtual public returns(bool);

    function redeem(uint i) virtual public returns (uint) {

        require(redeemAllowed());

        uint v = exchange.balanceOf(address(this));
        (uint bal, uint val) = redeem(v, v, _totalSupply, i);
        _totalSupply = _totalSupply.sub(bal);

        return val;
    }

    function destroy() virtual public {

        require(redeemAllowed());

        uint valTotal = exchange.balanceOf(address(this));
        uint valRemaining = valTotal;
        uint supplyTotal = _totalSupply;
        uint supplyRemaining = _totalSupply;
        
        for (uint i = 0; i < holders.length && valRemaining > 0; i++) {
            (uint bal, uint val) = redeem(valTotal, valTotal, supplyTotal, i);
            valRemaining = valRemaining.sub(val);
            supplyRemaining = supplyRemaining.sub(bal);
        }
        
        if (valRemaining > 0) {
            exchange.transferBalance(msg.sender, valRemaining);
        }

        if (supplyRemaining == 0) {
            selfdestruct(msg.sender);
        } else {
            _totalSupply = supplyRemaining;
        }
    }

    function redeem(uint valTotal, uint valRemaining, uint supplyTotal, uint i) 
        private
        returns (uint bal, uint val)
    {
        bal = balanceOf(holders[i]);
        
        if (bal > 0) {
            val = valTotal.mul(bal).div(supplyTotal);
            exchange.transferBalance(holders[i], val);
            valRemaining = valRemaining.sub(val);
            removeBalance(holders[i], bal);
        }
    }
}