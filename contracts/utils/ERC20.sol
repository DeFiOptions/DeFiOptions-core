pragma solidity >=0.6.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IERC20Details.sol";
import "../interfaces/IERC20Permit.sol";
import "../utils/SafeMath.sol";

abstract contract ERC20 is IERC20, IERC20Details, IERC20Permit {

    using SafeMath for uint;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => uint) public nonces;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    uint _totalSupply;

    constructor(string memory _name) public {

        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(_name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function decimals() override virtual external view returns (uint8) {
        return 18;
    }

    function totalSupply() override public view returns (uint) {

        return _totalSupply;
    }

    function balanceOf(address owner) override virtual public view returns (uint) {

        return balances[owner];
    }

    function allowance(address owner, address spender) override public view returns (uint) {

        return allowed[owner][spender];
    }

    function transfer(address to, uint value) override external returns (bool) {

        require(value <= balanceOf(msg.sender));
        require(to != address(0));

        removeBalance(msg.sender, value);
        addBalance(to, value);
        emitTransfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint value) override external returns (bool) {

        return approve(msg.sender, spender, value);
    }

    function transferFrom(address from, address to, uint value) override public returns (bool) {

        require(value <= balanceOf(from));
        require(value <= allowed[from][msg.sender]);
        require(to != address(0));

        removeBalance(from, value);
        addBalance(to, value);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
        emitTransfer(from, to, value);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        override
        external
    {
        require(deadline >= block.timestamp, "permit expired");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "invalid signature");
        approve(owner, spender, value);
    }

    function approve(address owner, address spender, uint value) private returns (bool) {

        require(spender != address(0));

        allowed[owner][spender] = value;
        emitApproval(owner, spender, value);
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