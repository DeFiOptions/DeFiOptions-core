pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../../contracts/utils/Arrays.sol";
import "../../contracts/utils/ERC20.sol";
import "../../contracts/utils/SafeMath.sol";

abstract contract RedeemableToken is ERC20 {

    using SafeMath for uint;

    OptionsExchange internal exchange;

    address[] internal holders;

    function redeemAllowed() virtual public returns(bool);

    function redeem(uint index) external returns (uint) {

        require(redeemAllowed(), "redeem not allowed");

        uint v = exchange.balanceOf(address(this));
        (uint bal, uint val) = redeem(v,  _totalSupply, index);
        _totalSupply = _totalSupply.sub(bal);

        return val;
    }

    function destroy() external {

        destroy(uint(-1));
    }

    function destroy(uint limit) public {

        require(redeemAllowed());

        uint valTotal = exchange.balanceOf(address(this));
        uint valRemaining = valTotal;
        uint supplyTotal = _totalSupply;
        uint supplyRemaining = _totalSupply;
        
        for (uint i = holders.length - 1; i != uint(-1) && limit != 0 && valRemaining > 0; i--) {
            (uint bal, uint val) = redeem(valTotal, supplyTotal, i);
            valRemaining = valRemaining.sub(val);
            supplyRemaining = supplyRemaining.sub(bal);
            Arrays.removeAtIndex(holders, i);
            limit--;
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

    function redeem(uint valTotal, uint supplyTotal, uint i) 
        private
        returns (uint bal, uint val)
    {
        bal = balanceOf(holders[i]);
        
        if (bal > 0) {
            uint b = 1e3;
            val = MoreMath.round(valTotal.mul(bal.mul(b)).div(supplyTotal), b);
            exchange.transferBalance(holders[i], val);
            removeBalance(holders[i], bal);
        }
    }
}