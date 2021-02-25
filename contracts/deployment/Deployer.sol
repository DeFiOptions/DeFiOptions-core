pragma solidity >=0.6.0;

import "../interfaces/UnderlyingFeed.sol";
import "./ManagedContract.sol";
import "./Proxy.sol";

contract Deployer {

    struct ContractData {
        string key;
        address origAddr;
        address proxyAddr;
    }

    mapping(string => address) private contractMap;
    mapping(string => string) private aliases;

    address private owner;
    address private original;
    ContractData[] private contracts;
    bool private deployed;

    constructor(address _owner, address _original) public {

        owner = _owner;
        original = _original;
    }

    function getOwner() public view returns (address) {

        return owner;
    }

    function hasKey(string memory key) public view returns (bool) {
        
        return contractMap[key] != address(0) || contractMap[aliases[key]] != address(0);
    }

    function addAlias(string memory fromKey, string memory toKey) public {
        
        ensureNotDeployed();
        ensureCaller();
        require(contractMap[toKey] != address(0), buildAddressNotSetMessage(toKey));
        aliases[fromKey] = toKey;
    }

    function getContractAddress(string memory key) public view returns (address) {

        if (original != address(0)) {
            if (Deployer(original).hasKey(key)) {
                return Deployer(original).getContractAddress(key);
            }
        }
        
        require(hasKey(key), buildAddressNotSetMessage(key));
        address addr = contractMap[key];
        if (addr == address(0)) {
            addr = contractMap[aliases[key]];
        }
        return addr;
    }

    function getPayableContractAddress(string memory key) public view returns (address payable) {

        return address(uint160(address(getContractAddress(key))));
    }

    function setContractAddress(string memory key) public {

        setContractAddress(key, msg.sender);
    }

    function setContractAddress(string memory key, address addr) public {

        ensureNotDeployed();
        ensureCaller();
        
        if (addr == address(0)) {
            contractMap[key] = address(0);
        } else {
            Proxy p = new Proxy(tx.origin, addr);
            contractMap[key] = address(p);
            contracts.push(ContractData(key, addr, address(p)));
        }
    }

    function isDeployed() public view returns(bool) {
        
        return deployed;
    }

    function deploy() public {

        ensureNotDeployed();
        ensureCaller();
        deployed = true;

        for (uint i = 0; i < contracts.length; i++) {
            if (contractMap[contracts[i].key] != address(0)) {
                ManagedContract(contracts[i].proxyAddr).initializeAndLock(this);
            }
        }
    }

    function reset() public {

        ensureCaller();
        deployed = false;

        for (uint i = 0; i < contracts.length; i++) {
            if (contractMap[contracts[i].key] != address(0)) {
                Proxy p = new Proxy(tx.origin, contracts[i].origAddr);
                contractMap[contracts[i].key] = address(p);
                contracts[i].proxyAddr = address(p);
            }
        }
    }

    function ensureNotDeployed() private view {

        require(!deployed, "already deployed");
    }

    function ensureCaller() private view {

        require(owner == address(0) || tx.origin == owner, "unallowed caller");
    }

    function buildAddressNotSetMessage(string memory key) private pure returns(string memory) {

        return string(abi.encodePacked("contract address not set: ", key));
    }
}