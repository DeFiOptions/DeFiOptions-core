pragma solidity >=0.6.0;

import "../utils/SafeMath.sol";

contract ERC20 {

    using SafeMath for uint;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    uint _totalSupply;

    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);

    function totalSupply() virtual public view returns (uint) {

        return _totalSupply;
    }

    function balanceOf(address owner) virtual public view returns (uint) {

        return balances[owner];
    }

    function allowance(address owner, address spender) virtual public view returns (uint) {

        return allowed[owner][spender];
    }

    function transfer(address to, uint value) virtual external returns (bool) {

        require(value <= balanceOf(msg.sender));
        require(to != address(0));

        removeBalance(msg.sender, value);
        addBalance(to, value);
        emitTransfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint value) virtual external returns (bool) {

        require(spender != address(0));

        allowed[msg.sender][spender] = value;
        emitApproval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) virtual public returns (bool) {

        require(value <= balanceOf(from));
        require(value <= allowed[from][msg.sender]);
        require(to != address(0));

        removeBalance(from, value);
        addBalance(to, value);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
        emitTransfer(from, to, value);
        return true;
    }

    function increaseAllowance(address spender, uint addedValue) virtual public returns (bool) {

        require(spender != address(0));

        allowed[msg.sender][spender] = (
            allowed[msg.sender][spender].add(addedValue));
        emitApproval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue) virtual public returns (bool) {

        require(spender != address(0));

        allowed[msg.sender][spender] = (
            allowed[msg.sender][spender].sub(subtractedValue));
        emitApproval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    function addBalance(address owner, uint value) virtual internal {

        balances[owner] = balanceOf(owner).add(value);
    }

    function removeBalance(address owner, uint value) virtual internal {

        balances[owner] = balanceOf(owner).sub(value);
    }

    function emitTransfer(address from, address to, uint value) virtual internal {

        emit Transfer(from, to, value);
    }

    function emitApproval(address owner, address spender, uint value) virtual internal {

        emit Approval(owner, spender, value);
    }
}