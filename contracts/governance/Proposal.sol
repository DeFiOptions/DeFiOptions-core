pragma solidity >=0.6.0;

import "./ProtocolSettings.sol";

abstract contract Proposal {

    function execute(ProtocolSettings _settings) public virtual;
}