pragma solidity >=0.6.0;

import "../../../contracts/utils/ERC20.sol";
import "../../../contracts/utils/SafeMath.sol";

contract ERC20Mock is ERC20 {

    using SafeMath for uint;

    function name() override external view returns (string memory) {
        return "ERC20Mock";
    }

    function symbol() override external view returns (string memory) {

        return "MOCK";
    }

    function decimals() override external view returns (uint8) {
        return 18;
    }

    function issue(address to, uint value) public {

        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
    }
}