pragma solidity >=0.6.0;

interface TimeProvider {

    function getNow() external view returns (uint);

}