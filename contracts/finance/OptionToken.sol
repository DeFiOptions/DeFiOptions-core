pragma solidity >=0.6.0;

import "../../contracts/finance/OptionsExchange.sol";
import "../../contracts/finance/RedeemableToken.sol";
import "../utils/ERC20.sol";
import "../utils/Arrays.sol";
import "../utils/SafeMath.sol";

contract OptionToken is RedeemableToken {

    using SafeMath for uint;

    mapping(address => uint) private _issued;

    string private constant _prefix = "Option Redeemable Token: ";
    string private _symbol;
    uint private _unliquidatedVolume;

    constructor(string memory _sb, address _issuer)
        ERC20(string(abi.encodePacked(_prefix, _sb)))
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

    function issue(address from, address to, uint value) external {

        require(msg.sender == address(exchange), "issuance unallowed");
        _issued[from] = _issued[from].add(value);
        addBalance(to, value);
        _totalSupply = _totalSupply.add(value);
        _unliquidatedVolume = _unliquidatedVolume.add(value);
        emit Transfer(address(0), to, value);
    }

    function burn(uint value) external {

        burn(msg.sender, value);
    }

    function burn(address owner, uint value) public {

        require(
            msg.sender == owner || msg.sender == address(exchange),
            "burn sender unallowed"
        );

        uint b = balanceOf(owner);
        uint w = _issued[owner];
        require(
            b >= value && w >= value || (msg.sender == address(exchange) && w >= value),
            "invalid burn value"
        );

        if (msg.sender == owner) {
            removeBalance(owner, value);
            _totalSupply = _totalSupply.sub(value);
        }
        
        _issued[owner] = w.sub(value);
        _unliquidatedVolume = _unliquidatedVolume.sub(value);

        exchange.cleanUp(address(this), owner);
    }

    function writtenVolume(address owner) external view returns (uint) {

        return _issued[owner];
    }

    function redeemAllowed() override public returns (bool) {
        
        return _unliquidatedVolume == 0;
    }

    function emitTransfer(address from, address to, uint value) override internal {

        exchange.transferOwnership(_symbol, from, to, value);
        emit Transfer(from, to, value);
    }
}