pragma solidity >=0.6.0;

import "../../../contracts/utils/ERC20.sol";
import "../../../contracts/utils/SafeMath.sol";

contract ERC20Mock is ERC20 {

    using SafeMath for uint;

    string private constant _name = "ERC20Mock";
    string private constant _symbol = "MOCK";

    constructor() ERC20(_name) public {

    }

    function name() override external view returns (string memory) {
        return _name;
    }

    function symbol() override external view returns (string memory) {

        return _symbol;
    }

    function issue(address to, uint value) public {

        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        emitTransfer(address(0), to, value);
    }
}