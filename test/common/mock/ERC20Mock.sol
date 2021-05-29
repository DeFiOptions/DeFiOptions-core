pragma solidity >=0.6.0;

import "../../../contracts/utils/ERC20.sol";
import "../../../contracts/utils/SafeMath.sol";

contract ERC20Mock is ERC20 {

    using SafeMath for uint;

    string private constant _name = "ERC20Mock";
    string private constant _symbol = "MOCK";

    uint8 private _decimals;

    constructor(uint8 decimals) ERC20(_name) public {

        _decimals = decimals;
    }

    function name() override external view returns (string memory) {

        return _name;
    }

    function symbol() override external view returns (string memory) {

        return _symbol;
    }

    function decimals() override external view returns (uint8) {

        return _decimals;
    }

    function reset() external {

        _totalSupply = 0;
    }

    function reset(address addr) external {

        removeBalance(addr, balanceOf(addr));
    }

    function issue(address to, uint value) external {

        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        emitTransfer(address(0), to, value);
    }
}