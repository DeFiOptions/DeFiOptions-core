pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../common/mock/ManagedContractMock.sol";

contract TestDeployer {

    function testContractInitialization() public {

        Deployer d = new Deployer(address(0), address(0));
        ManagedContractMock c = new ManagedContractMock(address(d));
        ManagedContractMock p = ManagedContractMock(
            d.getContractAddress("ManagedContract")
        );

        Assert.notEqual(address(p), address(c), "different addresses");

        Assert.isFalse(c.getInitialized(), "contract !initialized");
        Assert.isFalse(p.getInitialized(), "proxy !initialized");

        d.deploy();

        Assert.isFalse(c.getInitialized(), "contract !initialized again");
        Assert.isTrue(p.getInitialized(), "proxy initialized");
    }

    function testResetAndRedeploy() public {

        Deployer d = new Deployer(address(0), address(0));
        ManagedContractMock c = new ManagedContractMock(address(d));
        
        ManagedContractMock p1 = ManagedContractMock(
            d.getContractAddress("ManagedContract")
        );

        d.deploy();
        d.reset();
        
        ManagedContractMock p2 = ManagedContractMock(
            d.getContractAddress("ManagedContract")
        );

        d.deploy();

        Assert.notEqual(address(p1), address(c), "different addresses: p1, c");
        Assert.notEqual(address(p2), address(c), "different addresses: p2, c");
        Assert.notEqual(address(p1), address(p2), "different addresses: p1, p2");

        Assert.isFalse(c.getInitialized(), "contract !initialized");
        Assert.isTrue(p1.getInitialized(), "proxy 1 initialized");
        Assert.isTrue(p2.getInitialized(), "proxy 2 initialized");
    }

    function testMigrationInitialization() public {

        Deployer d = Deployer(DeployedAddresses.Deployer());
        
        d.deploy();
    }
}