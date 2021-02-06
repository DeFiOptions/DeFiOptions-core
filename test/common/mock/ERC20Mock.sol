pragma solidity >=0.6.0;

import "../../../contracts/utils/ERC20.sol";
import "../../../contracts/utils/SafeMath.sol";

contract ERC20Mock is ERC20 {

    using SafeMath for uint;

    function issue(address to, uint value) public {

        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
    }
}