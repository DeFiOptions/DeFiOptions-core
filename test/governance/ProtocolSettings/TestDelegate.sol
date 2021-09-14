pragma solidity >=0.6.0;

import "truffle/Assert.sol";
import "./Base.sol";

contract TestDelegate is Base {

    function testDelegateBalance() public {
        
        ShareHolder s1 = new ShareHolder(address(govToken));
        ShareHolder s2 = new ShareHolder(address(govToken));
        ShareHolder s3 = new ShareHolder(address(govToken));
        
        govToken.deposit(address(s1), abi.encode(1 ether));
        s1.delegateTo(address(s3));

        govToken.deposit(address(s2), abi.encode(1 ether));
        s2.delegateTo(address(s3));

        s3.delegateTo(address(s1));
        
        Assert.equal(0, govToken.delegateBalanceOf(address(s1)), "s1 delegate balance t0");
        Assert.equal(0, govToken.delegateBalanceOf(address(s2)), "s2 delegate balance t0");
        Assert.equal(2 ether, govToken.delegateBalanceOf(address(s3)), "s3 delegate balance t0");
        
        Assert.equal(1 ether, govToken.balanceOf(address(s1)), "s1 balance t0");
        Assert.equal(1 ether, govToken.balanceOf(address(s2)), "s2 balance t0");
        Assert.equal(0, govToken.balanceOf(address(s3)), "s3 balance t0");

        s2.transfer(address(s3), 1 ether / 2);
        
        Assert.equal(1 ether / 2, govToken.delegateBalanceOf(address(s1)), "s1 delegate balance t1");
        Assert.equal(0, govToken.delegateBalanceOf(address(s2)), "s2 delegate balance t1");
        Assert.equal(3 ether / 2, govToken.delegateBalanceOf(address(s3)), "s3 delegate balance t1");
        
        Assert.equal(1 ether, govToken.balanceOf(address(s1)), "s1 balance t1");
        Assert.equal(1 ether / 2, govToken.balanceOf(address(s2)), "s2 balance t1");
        Assert.equal(1 ether / 2, govToken.balanceOf(address(s3)), "s3 balance t1");
    }

    function testDelegateSupressingHotVoting() public {
        
        ShareHolder s1 = new ShareHolder(address(govToken));
        ShareHolder s2 = new ShareHolder(address(govToken));
        
        govToken.deposit(address(s1), abi.encode(1 ether));
        bytes4 sig = bytes4(keccak256(bytes("delegateTo(address,bool)")));

        (bool r1,) = address(s1).call(
            abi.encodePacked(
                sig,
                abi.encode(address(s2), true)
            )
        );
        
        Assert.isFalse(r1, "delegateTo supressing hot voting should fail");

        (bool r2,) = address(s1).call(
            abi.encodePacked(
                sig,
                abi.encode(address(s2), false)
            )
        );
        
        Assert.isTrue(r2, "delegateTo not supressing hot voting should succeed");
    }
}