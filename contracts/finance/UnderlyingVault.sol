pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../governance/ProtocolSettings.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router01.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeERC20.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./CreditProvider.sol";

contract UnderlyingVault is ManagedContract {

    using SafeERC20 for IERC20;
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

    function lock(address owner, address token, uint value) external {

        ensureCaller();
        
        require(owner != address(0), "invalid owner");
        require(token != address(0), "invalid token");

        allocation[owner][token] = allocation[owner][token].add(value);
        emit Lock(owner, token, value);
    }

    function liquidate(
        address owner,
        address token,
        address feed,
        uint amountOut
    )
        external
        returns (uint _in, uint _out)
    {
        ensureCaller();
        
        require(owner != address(0), "invalid owner");
        require(token != address(0), "invalid token");
        require(feed != address(0), "invalid feed");

        uint balance = balanceOf(owner, token);

        if (balance > 0) {

            (address _router, address _stablecoin) = settings.getSwapRouterInfo();
            require(
                _router != address(0) && _stablecoin != address(0),
                "invalid swap router settings"
            );

            IUniswapV2Router01 router = IUniswapV2Router01(_router);
            (, int p) = UnderlyingFeed(feed).getLatestPrice();

            address[] memory path = settings.getSwapPath(
                UnderlyingFeed(feed).getUnderlyingAddr(),
                _stablecoin
            );

            (_in, _out) = swapUnderlyingForStablecoin(
                owner,
                router,
                path,
                p,
                balance,
                amountOut
            );

            allocation[owner][token] = allocation[owner][token].sub(_in);
            emit Liquidate(owner, token, _in, _out);
        }
    }

    function release(address owner, address token, address feed, uint value) external {
        
        ensureCaller();
        
        require(owner != address(0), "invalid owner");
        require(token != address(0), "invalid token");
        require(feed != address(0), "invalid feed");

        uint bal = allocation[owner][token];
        value = MoreMath.min(bal, value);

        if (bal > 0) {
            address underlying = UnderlyingFeed(feed).getUnderlyingAddr();
            allocation[owner][token] = bal.sub(value);
            IERC20(underlying).safeTransfer(owner, value);
            emit Release(owner, token, value);
        }
    }

    function swapUnderlyingForStablecoin(
        address owner,
        IUniswapV2Router01 router,
        address[] memory path,
        int price,
        uint balance,
        uint amountOut
    )
        private
        returns (uint _in, uint _out)
    {
        require(path.length >= 2, "invalid swap path");
        
        uint amountInMax = getAmountInMax(
            price,
            amountOut,
            path
        );

        if (amountInMax > balance) {
            amountOut = amountOut.mul(balance).div(amountInMax);
            amountInMax = balance;
        }

        (uint r, uint b) = settings.getTokenRate(path[path.length - 1]);
        IERC20(path[0]).safeApprove(address(router), amountInMax);

        _out = amountOut;
        _in = router.swapTokensForExactTokens(
            amountOut.mul(r).div(b),
            amountInMax,
            path,
            address(creditProvider),
            time.getNow()
        )[0];

        if (amountOut > 0) {
            creditProvider.addBalance(owner, path[path.length - 1], amountOut.mul(r).div(b));
        }
    }

    function getAmountInMax(
        int price,
        uint amountOut,
        address[] memory path
    )
        private
        view
        returns (uint amountInMax)
    {
        uint8 d = IERC20Details(path[0]).decimals();
        amountInMax = amountOut.mul(10 ** uint(d)).div(uint(price));
        
        (uint rTol, uint bTol) = settings.getSwapRouterTolerance();
        amountInMax = amountInMax.mul(rTol).div(bTol);
    }

    function ensureCaller() private view {
        
        require(callers[msg.sender] == 1, "unauthorized caller");
    }
}