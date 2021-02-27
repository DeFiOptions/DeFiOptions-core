pragma solidity >=0.6.0;

import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/interfaces/LiquidityPool.sol";
import "../../../contracts/utils/ERC20.sol";

contract PoolTrader {
    
    ERC20 private erc20;
    OptionsExchange private exchange;
    LiquidityPool private pool;
    
    address private addr;
    uint private volumeBase = 1e9;
    
    constructor(address _erc20, address _exchange, address _pool) public {

        erc20 = ERC20(_erc20);
        exchange = OptionsExchange(_exchange);
        pool = LiquidityPool(_pool);
        addr = address(this);
    }
    
    function balance() external view returns (uint) {
        
        return erc20.balanceOf(addr);
    }
    
    function approve(address spender, uint value) external {
        
        erc20.approve(spender, value);
    }

    function depositInExchange(uint value) external {

        erc20.approve(address(exchange), value);
        exchange.depositTokens(address(this), address(erc20), value);
    }

    function writeOptions(
        uint volume,
        OptionsExchange.OptionType optType,
        uint strike, 
        uint maturity
    )
        public
        returns (uint id)
    {
        id = exchange.writeOptions(
            address(0), volume * volumeBase, optType, strike, maturity
        );
    }
    
    function buyFromPool(string calldata code, uint price, uint volume, address token)
        external
        returns (address)
    {    
        erc20.approve(address(pool), price * volume / volumeBase);
        return pool.buy(code, price, volume, token);
    }
    
    function sellToPool(string calldata code, uint price, uint volume) external {
        
        ERC20(exchange.resolveToken(code)).approve(address(pool), price * volume / volumeBase);
        pool.sell(code, price, volume);
    }
}