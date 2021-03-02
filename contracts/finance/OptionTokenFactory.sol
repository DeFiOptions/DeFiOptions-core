pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "./OptionToken.sol";

contract OptionTokenFactory is ManagedContract {

    constructor(address deployer) public {

        Deployer(deployer).setContractAddress("OptionTokenFactory");
    }

    function initialize(Deployer deployer) override internal {

    }

    function create(string calldata symbol) external returns (address) {

        return address(new OptionToken(symbol, msg.sender));
    }
}