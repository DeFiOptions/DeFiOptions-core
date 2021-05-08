pragma solidity >=0.6.0;

import "./ManagedContract.sol";
import "./Proxy.sol";

contract Deployer {

    struct ContractData {
        string key;
        address origAddr;
    }

    mapping(string => address) private contractMap;
    mapping(string => string) private aliases;

    address private owner;
    ContractData[] private contracts;
    bool private deployed;

    constructor(address _owner) public {

        owner = _owner;
    }

    function getOwner() public view returns (address) {

        return owner;
    }

    function hasKey(string memory key) public view returns (bool) {
        
        return contractMap[key] != address(0) || contractMap[aliases[key]] != address(0);
    }

    function setContractAddress(string memory key, address addr) public {

        ensureNotDeployed();
        ensureCaller();
        
        contracts.push(ContractData(key, addr));
        contractMap[key] = address(1);
    }

    function addAlias(string memory fromKey, string memory toKey) public {
        
        ensureNotDeployed();
        ensureCaller();
        require(contractMap[toKey] != address(0), buildAddressNotSetMessage(toKey));
        aliases[fromKey] = toKey;
    }

    function getContractAddress(string memory key) public view returns (address) {
        
        require(hasKey(key), buildAddressNotSetMessage(key));
        address addr = contractMap[key];
        if (addr == address(0)) {
            addr = contractMap[aliases[key]];
        }
        require(addr != address(1), buildProxyNotDeployedMessage(key));
        return addr;
    }

    function getPayableContractAddress(string memory key) public view returns (address payable) {

        return address(uint160(address(getContractAddress(key))));
    }

    function isDeployed() public view returns(bool) {
        
        return deployed;
    }

    function deploy() public {

        ensureNotDeployed();
        ensureCaller();
        deployed = true;

        for (uint i = contracts.length - 1; i != uint(-1); i--) {
            if (contractMap[contracts[i].key] == address(1)) {
                Proxy p = new Proxy(getOwner(), contracts[i].origAddr);
                contractMap[contracts[i].key] = address(p);
            } else {
                contracts[i] = contracts[contracts.length - 1];
                contracts.pop();
            }
        }

        for (uint i = 0; i < contracts.length; i++) {
            address p = contractMap[contracts[i].key];
            ManagedContract(p).initializeAndLock(this);
        }
    }

    function reset() public {

        ensureCaller();
        deployed = false;

        for (uint i = 0; i < contracts.length; i++) {
            contractMap[contracts[i].key] = address(1);
        }
    }

    function ensureNotDeployed() private view {

        require(!deployed, "already deployed");
    }

    function ensureCaller() private view {

        require(owner == address(0) || msg.sender == owner, "unallowed caller");
    }

    function buildAddressNotSetMessage(string memory key) private pure returns(string memory) {

        return string(abi.encodePacked("contract address not set: ", key));
    }

    function buildProxyNotDeployedMessage(string memory key) private pure returns(string memory) {

        return string(abi.encodePacked("proxy not deployed: ", key));
    }
}