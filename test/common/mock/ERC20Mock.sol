pragma solidity >=0.6.0;

import "../../../contracts/deployment/ManagedContract.sol";
import "../../../contracts/utils/ERC20.sol";
import "../../../contracts/utils/SafeMath.sol";

contract ERC20Mock is ERC20, ManagedContract {

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

    function issue(address to, uint value) public {

        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        emitTransfer(address(0), to, value);
    }
}