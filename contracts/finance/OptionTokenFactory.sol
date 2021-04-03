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

    function create(string calldata symbol, address udlFeed) external returns (address) {

        bytes memory sb1 = bytes(UnderlyingFeed(udlFeed).symbol());
        bytes memory sb2 = bytes(symbol);
        for (uint i = 0; i < sb1.length; i++) {
            if (sb1[i] != sb2[i]) {
                revert("invalid feed");
            }
        }
        return address(new OptionToken(symbol, msg.sender));
    }
}