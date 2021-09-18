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
    uint private locked; // 1 = Initialized; 2 = Non upgradable
    // --------------------------------------------------------

    function initializeAndLock(Deployer deployer) public {

        require(locked == 0, "initialization locked");
        locked = 1;
        initialize(deployer);
    }

    function initialize(Deployer deployer) virtual internal {

    }

    function getOwner() public view returns (address) {

        return owner;
    }

    function getImplementation() public view returns (address) {

        return implementation;
    }
}