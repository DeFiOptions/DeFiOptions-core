pragma solidity >=0.6.0;

import "./ProtocolSettings.sol";

abstract contract Proposal {

    function getName() public virtual view returns (string memory);

    function execute(ProtocolSettings _settings) public virtual;
}