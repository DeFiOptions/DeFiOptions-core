pragma solidity >=0.6.0;

interface LiquidityPool {

    event AddSymbol(string indexed optSymbol);
    
    event RemoveSymbol(string indexed optSymbol);

    event Buy(string indexed optSymbol, uint price, uint volume, address token);
    
    event Sell(string indexed optSymbol, uint price, uint volume);

    function maturity() external view returns (uint);

    function yield(uint dt) external view returns (uint y);

    function depositTokens(address to, address token, uint value) external;

    function listSymbols() external view returns (string memory);

    function queryBuy(string calldata optSymbol) external view returns (uint price, uint volume);

    function querySell(string calldata optSymbol) external view returns (uint price, uint volume);

    function buy(string calldata optSymbol, uint price, uint volume, address token)
        external
        returns (address addr);

    function sell(string calldata optSymbol, uint price, uint volume) external;
}
