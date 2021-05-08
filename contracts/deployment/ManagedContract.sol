pragma solidity ^0.6.0;

import "./Deployer.sol";

contract ManagedContract {

    // ATTENTION: storage variable alignment
    address private owner;
    address private pendingOwner;
    address private implementation;
    bool private locked;
    // -------------------------------------

    function initializeAndLock(Deployer deployer) public {

        require(!locked, "initialization locked");
        locked = true;
        initialize(deployer);
    }

    function initialize(Deployer deployer) virtual internal {

    }

    function getImplementation() internal view returns (address) {

        return implementation;
    }
}