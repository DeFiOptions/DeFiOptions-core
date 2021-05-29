pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../governance/ProtocolSettings.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router01.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./CreditProvider.sol";

contract UnderlyingVault is ManagedContract {

    using SafeMath for uint;
    using SignedSafeMath for int;

    TimeProvider private time;
    ProtocolSettings private settings;
    CreditProvider private creditProvider;
    
    mapping(address => uint) private callers;
    mapping(address => mapping(address => uint)) private allocation;

    event Lock(address indexed owner, address indexed token, uint value);

    event Liquidate(address indexed owner, address indexed token, uint valueIn, uint valueOut);

    event Release(address indexed owner, address indexed token, uint value);

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        
        callers[deployer.getContractAddress("OptionsExchange")] = 1;
    }

    function balanceOf(address owner, address token) public view returns (uint) {

        return allocation[owner][token];
    }

    function lock(address owner, address token, address underlying, uint value) external {

        ensureCaller();
        
        require(owner != address(0), "invalid owner");
        require(token != address(0), "invalid token");
        require(underlying != address(0), "invalid underlying");

        allocation[owner][token] = allocation[owner][token].add(value);
        emit Lock(owner, token, value);
    }

    function liquidate(
        address owner,
        address token,
        address underlying,
        uint amountOut
    )
        external
        returns (uint v)
    {
        ensureCaller();
        
        require(owner != address(0), "invalid owner");
        require(token != address(0), "invalid token");
        require(underlying != address(0), "invalid underlying");

        uint balance = balanceOf(owner, token);

        if (balance > 0) {

            (address _router, address _stablecoin) = settings.getSwapRouterInfo();
            require(
                _router != address(0) && _stablecoin != address(0),
                "invalid swap router settings"
            );

            IUniswapV2Router01 router = IUniswapV2Router01(_router);

            address[] memory path = new address[](2);
            path[0] = underlying;
            path[1] = _stablecoin;

            (uint _in, uint _out) = swapUnderlyingForStablecoin(
                owner,
                router,
                path,
                balance,
                amountOut
            );

            v = _in;
            allocation[owner][token] = allocation[owner][token].sub(_in);
            emit Liquidate(owner, token, _in, _out);
        }
    }

    function release(address owner, address token, address underlying, uint value) external {
        
        ensureCaller();
        
        require(owner != address(0), "invalid owner");
        require(token != address(0), "invalid token");
        require(underlying != address(0), "invalid underlying");

        uint bal = allocation[owner][token];
        value = MoreMath.min(bal, value);

        if (bal > 0) {
            allocation[owner][token] = bal.sub(value);
            IERC20(underlying).transfer(owner, value);
            emit Release(owner, token, value);
        }
    }

    function swapUnderlyingForStablecoin(
        address owner,
        IUniswapV2Router01 router,
        address[] memory path,
        uint balance,
        uint amountOut
    )
        private
        returns (uint _in, uint _out)
    {                
        (uint r, uint b) = settings.getTokenRate(path[1]);
        uint amountInMax = router.getAmountsIn(
            amountOut.mul(r).div(b),
            path
        )[0];
        
        (uint rTol, uint bTol) = settings.getSwapRouterTolerance();
        amountInMax = amountInMax.mul(rTol).div(bTol);
        if (amountInMax > balance) {
            amountOut = amountOut.mul(balance).div(amountInMax);
            amountInMax = balance;
        }
        IERC20(path[0]).approve(address(router), amountInMax);

        _out = amountOut;
        _in = router.swapTokensForExactTokens(
            amountOut.mul(r).div(b),
            amountInMax,
            path,
            address(creditProvider),
            time.getNow()
        )[0];

        if (amountOut > 0) {
            creditProvider.addBalance(owner, path[1], amountOut.mul(r).div(b));
        }
    }

    function ensureCaller() private view {
        
        require(callers[msg.sender] == 1, "unauthorized caller");
    }
}