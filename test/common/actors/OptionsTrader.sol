pragma solidity >=0.6.0;

import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/interfaces/TimeProvider.sol";

contract OptionsTrader {
    
    OptionsExchange private exchange;
    TimeProvider private time;
    
    address private addr;
    address private feed;
    uint private volumeBase = 1e18;
    
    constructor(address _exchange, address _time, address _feed) public {

        exchange = OptionsExchange(_exchange);
        time = TimeProvider(_time);
        addr = address(this);
        feed = _feed;
    }
    
    function balance() public view returns (uint) {
        
        return exchange.balanceOf(addr);
    }
    
    function withdrawTokens() public {
        
        exchange.withdrawTokens(calcSurplus());
    }
    
    function withdrawTokens(uint amount) public {
        
        exchange.withdrawTokens(amount);
    }

    function writeOption(
        OptionsExchange.OptionType optType,
        int strike, 
        uint timeTomaturity
    )
        public
        returns (uint id)
    {
        id = writeOptions(1, optType, strike, timeTomaturity);
    }

    function writeOptions(
        uint volume,
        OptionsExchange.OptionType optType,
        int strike, 
        uint timeToMaturity
    )
        public
        returns (uint id)
    {
        id = exchange.writeOptions(
            feed, volume * volumeBase, optType, uint(strike), time.getNow() + timeToMaturity
        );
    }

    function liquidateOptions(uint id) public {
        
        exchange.liquidateOptions(id);
    }

    function transferOptions(address to, uint id, uint volume) public {

        OptionToken(exchange.resolveToken(id)).transfer(to, volume * volumeBase);
    }

    function burnOptions(uint id, uint volume) public {

        OptionToken(exchange.resolveToken(id)).burn(volume * volumeBase);
    }
    
    function calcCollateral() public view returns (uint) {
        
        return exchange.calcCollateral(addr);
    }
    
    function calcSurplus() public view returns (uint) {
        
        return exchange.calcSurplus(addr);
    }
    
    function calcDebt() public view returns (uint) {
        
        return exchange.calcDebt(addr);
    }
}