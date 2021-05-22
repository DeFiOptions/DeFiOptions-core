pragma solidity >=0.6.0;

import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/deployment/ManagedContract.sol";

contract ManagedContractMock is ManagedContract {
    
    bool initialized;
    
    function initialize(Deployer deployer) override internal {

        require(address(deployer) != address(0), "invalid deployer variable");
        require(deployer.getContractAddress("ManagedContract") == address(this), "invalid contract address");
        initialized = true;
    }

    function getInitialized() public view returns(bool) {

        return initialized;
    }
}