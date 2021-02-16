pragma solidity >=0.6.0;

interface LiquidityPool {

    event AddCode(string indexed code);
    
    event RemoveCode(string indexed code);

    function depositTokens(address to, address token, uint value) external;

    function queryBuy(string calldata code) external view returns (uint price, uint volume);

    function querySell(string calldata code) external view returns (uint price, uint volume);

    function buy(string calldata code, uint price, uint volume, address token) external;

    function sell(string calldata code, uint price, uint volume) external;

}