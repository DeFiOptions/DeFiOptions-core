pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../common/mock/ERC20Mock.sol";
import "../../common/mock/EthFeedMock.sol";
import "../../common/mock/ManagedContractMock.sol";
import "../../common/mock/TimeProviderMock.sol";
import "../../common/mock/UniswapV2RouterMock.sol";

contract TestDeployer {

    function testContractInitialization() public {

        Deployer d = new Deployer(address(0));
        
        ManagedContractMock c = new ManagedContractMock();
        d.setContractAddress("ManagedContract", address(c));

        Assert.isFalse(c.getInitialized(), "contract !initialized");

        d.deploy();

        ManagedContractMock p = ManagedContractMock(
            d.getContractAddress("ManagedContract")
        );

        Assert.notEqual(address(p), address(c), "different addresses");

        Assert.isFalse(c.getInitialized(), "contract !initialized again");
        Assert.isTrue(p.getInitialized(), "proxy initialized");
    }

    function testResetAndRedeploy() public {

        Deployer d = new Deployer(address(0));

        ManagedContractMock c = new ManagedContractMock();
        d.setContractAddress("ManagedContract", address(c));

        d.deploy();
        
        ManagedContractMock p1 = ManagedContractMock(
            d.getContractAddress("ManagedContract")
        );
        
        d.reset();
        d.deploy();
        
        ManagedContractMock p2 = ManagedContractMock(
            d.getContractAddress("ManagedContract")
        );

        Assert.notEqual(address(p1), address(c), "different addresses: p1, c");
        Assert.notEqual(address(p2), address(c), "different addresses: p2, c");
        Assert.notEqual(address(p1), address(p2), "different addresses: p1, p2");

        Assert.isFalse(c.getInitialized(), "contract !initialized");
        Assert.isTrue(p1.getInitialized(), "proxy 1 initialized");
        Assert.isTrue(p2.getInitialized(), "proxy 2 initialized");
    }

    function testUpgradeImplementationFromOwnerAddress() public {

        Deployer d = new Deployer(address(0));
        
        ManagedContractMock c1 = new ManagedContractMock();
        d.setContractAddress("ManagedContract", address(c1));

        d.deploy(address(this));
        Proxy p = Proxy(
            d.getPayableContractAddress("ManagedContract")
        );

        Assert.equal(getImplementation(p), address(c1), "initial implementation");

        ManagedContractMock c2 = new ManagedContractMock();

        (bool success,) = address(p).call(
            abi.encodePacked(
                p.setImplementation.selector,
                abi.encode(address(c2))
            )
        );

        Assert.isTrue(success, "setImplementation should succed");
        Assert.equal(getImplementation(p), address(c2), "updated implementation");
        Assert.notEqual(address(c1), address(c2), "different addresses");
    }

    function testUpgradeImplementationFromAnotherAddress() public {

        Deployer d = new Deployer(address(0));
        
        ManagedContractMock c1 = new ManagedContractMock();
        d.setContractAddress("ManagedContract", address(c1));

        d.deploy(address(0x0000000000000000000000000000000000000001));
        Proxy p = Proxy(
            d.getPayableContractAddress("ManagedContract")
        );

        ManagedContractMock c2 = new ManagedContractMock();

        (bool success,) = address(p).call(
            abi.encodePacked(
                p.setImplementation.selector,
                abi.encode(address(c2))
            )
        );

        Assert.isFalse(success, "setImplementation should fail");
    }

    function testSetNonUpgradable() public {

        Deployer d = new Deployer(address(0));
        
        ManagedContractMock c1 = new ManagedContractMock();
        d.setContractAddress("ManagedContract", address(c1));

        d.deploy(address(this));
        Proxy p = Proxy(
            d.getPayableContractAddress("ManagedContract")
        );

        ManagedContractMock c2 = new ManagedContractMock();

        (bool s1,) = address(p).call(
            abi.encodePacked(
                p.setImplementation.selector,
                abi.encode(address(c2))
            )
        );
        Assert.isTrue(s1, "setImplementation should succed");

        p.setNonUpgradable();

        (bool s2,) = address(p).call(
            abi.encodePacked(
                p.setImplementation.selector,
                abi.encode(address(c2))
            )
        );
        Assert.isFalse(s2, "setImplementation should fail");
    }

    function testMigrationInitialization() public {

        Deployer d = Deployer(DeployedAddresses.Deployer());
        
        d.deploy();
    }

    function getImplementation(Proxy p) private view returns (address) {

        return ManagedContract(address(p)).getImplementation();
    }
}
