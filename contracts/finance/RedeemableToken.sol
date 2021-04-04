pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../../contracts/utils/Arrays.sol";
import "../../contracts/utils/ERC20.sol";
import "../../contracts/utils/SafeMath.sol";

abstract contract RedeemableToken is ERC20 {

    using SafeMath for uint;

    OptionsExchange internal exchange;

    function redeemAllowed() virtual public returns(bool);

    function redeem(address owner) external returns (uint) {

        address[] memory owners = new address[](1);
        owners[0] = owner;
        redeem(owners);
    }

    function redeem(address[] memory owners) public returns (uint) {

        require(redeemAllowed(), "redeemd not allowed");

        uint valTotal = exchange.balanceOf(address(this));
        uint valRemaining = valTotal;
        uint supplyTotal = _totalSupply;
        uint supplyRemaining = _totalSupply;
        
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] != address(0)) {
                (uint bal, uint val) = redeem(valTotal, supplyTotal, owners[i]);
                valRemaining = valRemaining.sub(val);
                supplyRemaining = supplyRemaining.sub(bal);
            }
        }

        _totalSupply = supplyRemaining;
    }

    function redeem(uint valTotal, uint supplyTotal, address owner) 
        private
        returns (uint bal, uint val)
    {
        bal = balanceOf(owner);
        
        if (bal > 0) {
            uint b = 1e3;
            val = MoreMath.round(valTotal.mul(bal.mul(b)).div(supplyTotal), b);
            exchange.transferBalance(owner, val);
            removeBalance(owner, bal);
        }
    }
}