pragma solidity ^0.6.0;

import "./Deployer.sol";
// *** IMPORTANT ***
// "onwer" storage variable must be set to a GnosisSafe multisig wallet address:
// - https://github.com/gnosis/safe-contracts/blob/main/contracts/GnosisSafe.sol

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

    function getOwner() internal view returns (address) {

        return owner;
    }

    function getImplementation() internal view returns (address) {

        return implementation;
    }
}