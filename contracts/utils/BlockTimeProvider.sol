pragma solidity >=0.6.0;

import "../../contracts/deployment/Deployer.sol";
import "../../contracts/deployment/ManagedContract.sol";
import "../../contracts/interfaces/TimeProvider.sol";

contract BlockTimeProvider is TimeProvider, ManagedContract {
    
    constructor(address deployer) public {

        if (deployer != address(0)) {
            Deployer(deployer).setContractAddress("TimeProvider");
        }
    }
    
    function getNow() override external view returns (uint) {
        return block.timestamp;
    }
}