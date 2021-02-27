pragma solidity >=0.6.0;

import "../../../contracts/interfaces/LiquidityPool.sol";
import "../../../contracts/utils/ERC20.sol";

contract PoolTrader {
    
    ERC20 private erc20;
    LiquidityPool private pool;
    
    address private addr;
    uint private volumeBase = 1e9;
    
    constructor(address _erc20, address _pool) public {

        erc20 = ERC20(_erc20);
        pool = LiquidityPool(_pool);
        addr = address(this);
    }
    
    function balance() external view returns (uint) {
        
        return erc20.balanceOf(addr);
    }
    
    function approve(address spender, uint value) external {
        
        erc20.approve(spender, value);
    }
    
    function buy(string calldata code, uint price, uint volume, address token)
        external
        returns (address)
    {    
        erc20.approve(address(pool), price * volume / volumeBase);
        return pool.buy(code, price, volume, token);
    }
    
    function sell(string calldata code, uint price, uint volume) external {
        
        pool.sell(code, price, volume);
    }
}