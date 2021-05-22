pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../interfaces/TimeProvider.sol";

contract BlockTimeProvider is TimeProvider, ManagedContract {
    
    function getNow() override external view returns (uint) {
        
        return block.timestamp;
    }
}