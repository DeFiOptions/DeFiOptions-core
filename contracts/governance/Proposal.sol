pragma solidity >=0.6.0;

import "./ProtocolSettings.sol";

abstract contract Proposal {

    function getName() public virtual returns (string memory);

    function execute(ProtocolSettings _settings) public virtual;
}