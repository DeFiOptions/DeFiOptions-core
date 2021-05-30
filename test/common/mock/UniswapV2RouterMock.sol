pragma solidity >=0.6.0;

import "../../../contracts/deployment/ManagedContract.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../../contracts/interfaces/IUniswapV2Router01.sol";
import "../../../contracts/interfaces/UnderlyingFeed.sol";
import "../../../contracts/utils/ERC20.sol";
import "../../../contracts/utils/SafeMath.sol";
import "../../common/mock/ERC20Mock.sol";

contract UniswapV2RouterMock is ManagedContract, IUniswapV2Router01 {

    using SafeMath for uint;

    ProtocolSettings private settings;
    UnderlyingFeed private feed;
    ERC20 private underlying;
    ERC20Mock private stablecoin;

    function initialize(Deployer deployer) override internal {

        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        feed = UnderlyingFeed(deployer.getContractAddress("UnderlyingFeed"));
        underlying = ERC20(feed.getUnderlyingAddr());
        stablecoin = ERC20Mock(deployer.getContractAddress("StablecoinA"));
    }

    function factory() override external pure returns (address) {

        return address(0);
    }

    function WETH() override external pure returns (address){

        revert("not implemented");
    }

    function addLiquidity(
        address,
        address,
        uint,
        uint,
        uint,
        uint,
        address,
        uint
    )
        override
        external
        returns (uint, uint, uint)
    {
        revert("not implemented");
    }

    function addLiquidityETH(
        address,
        uint,
        uint,
        uint,
        address,
        uint
    )
        override
        external
        payable
        returns (uint, uint, uint)
    {
        revert("not implemented");
    }

    function removeLiquidity(
        address,
        address,
        uint,
        uint,
        uint,
        address,
        uint
    )
        override
        external
        returns (uint, uint)
    {
        revert("not implemented");
    }

    function removeLiquidityETH(
        address,
        uint,
        uint,
        uint,
        address,
        uint
    )
        override
        external
        returns (uint, uint)
    {
        revert("not implemented");
    }

    function removeLiquidityWithPermit(
        address,
        address,
        uint,
        uint,
        uint,
        address,
        uint,
        bool, uint8, bytes32, bytes32
    )
        override
        external
        returns (uint, uint)
    {
        revert("not implemented");
    }

    function removeLiquidityETHWithPermit(
        address,
        uint,
        uint,
        uint,
        address,
        uint,
        bool, uint8, bytes32, bytes32
    )
        override
        external
        returns (uint, uint)
    {
        revert("not implemented");
    }

    function swapExactTokensForTokens(
        uint,
        uint,
        address[] calldata,
        address,
        uint
    )
        override
        external
        returns (uint[] memory)
    {
        revert("not implemented");
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint
    )
        override
        external
        returns (uint[] memory amounts)
    {
        require(
            path[0] == address(underlying) && path[1] == address(stablecoin),
            "invalid path"
        );

        (uint r, uint b) = settings.getTokenRate(path[1]);
        (, int p) = feed.getLatestPrice();
        uint v = amountOut.mul(10 ** uint(underlying.decimals())).div(uint(p).mul(r).div(b));

        require(v <= amountInMax, "amountInMax exceeded");
        underlying.transferFrom(msg.sender, address(this), v);
        stablecoin.issue(to, amountOut);

        amounts = new uint[](2);
        amounts[0] = v;
        amounts[1] = amountOut;
    }

    function swapExactETHForTokens(
        uint,
        address[] calldata,
        address,
        uint
    )
        override
        external
        payable
        returns (uint[] memory)
    {
        revert("not implemented");
    }

    function swapTokensForExactETH(
        uint,
        uint,
        address[] calldata,
        address,
        uint
    )
        override
        external
        returns (uint[] memory)
    {
        revert("not implemented");
    }

    function swapExactTokensForETH(
        uint,
        uint,
        address[] calldata,
        address,
        uint
    )
        override
        external
        returns (uint[] memory)
    {
        revert("not implemented");
    }

    function swapETHForExactTokens(
        uint,
        address[] calldata,
        address,
        uint
    )
        override
        external
        payable
        returns (uint[] memory)
    {
        revert("not implemented");
    }

    function quote(
        uint,
        uint,
        uint
    )
        override
        external
        pure
        returns (uint)
    {
        revert("not implemented");
    }

    function getAmountOut(
        uint,
        uint,
        uint
    )
        override
        external
        pure
        returns (uint)
    {
        revert("not implemented");
    }

    function getAmountIn(
        uint,
        uint,
        uint
    )
        override
        external
        pure
        returns (uint)
    {
        revert("not implemented");
    }

    function getAmountsOut(
        uint,
        address[] calldata
    )
        override
        external
        view
        returns (uint[] memory)
    {
        revert("not implemented");
    }

    function getAmountsIn(
        uint,
        address[] calldata
    )
        override
        external
        view
        returns (uint[] memory)
    {
        revert("not implemented");
    }
}