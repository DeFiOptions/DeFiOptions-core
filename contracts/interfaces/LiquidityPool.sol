pragma solidity >=0.6.0;

interface LiquidityPool {

    event AddSymbol(string indexed symbol);
    
    event RemoveSymbol(string indexed symbol);

    function depositTokens(address to, address token, uint value) external;

    function queryBuy(string calldata symbol) external view returns (uint price, uint volume);

    function querySell(string calldata symbol) external view returns (uint price, uint volume);

    function buy(string calldata symbol, uint price, uint volume, address token)
        external
        returns (address addr);

    function sell(string calldata symbol, uint price, uint volume) external;

}