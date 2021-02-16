pragma solidity >=0.6.0;

import "../finance/OptionsExchange.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/LiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract LinearLiquidityPool is LiquidityPool {

    using SafeMath for uint;
    using SignedSafeMath for int;

    struct Fraction {
        uint n;
        uint d;
    }

    struct PricingParameters {
        address udlFeed;
        uint k1;
        Fraction k2;
        Fraction k3;
        uint timespan;
    }

    TimeProvider private time;
    OptionsExchange private exchange;

    mapping(string => PricingParameters) private parameters;
    mapping(string => uint) private buyStock;
    mapping(string => uint) private sellStock;

    Fraction private spread;
    Fraction private unallocatedBalance;

    constructor() public {

        // TODO: initialize parameters
    }

    function addCode(string calldata code) external {

        // TODO: register tradable option and pricing model parameters
        emit AddCode(code);
    }
    
    function removeCode(string calldata code) external {

        // TODO: remove tradable option
        emit removeCode(code);
    }

    function queryBuy(string calldata code)
        override
        external
        view
        returns (uint price, uint volume)
    {
        ensureValidCode(code);

        PricingParameters memory p = parameters[code];

        price = calcPrice(p, Fraction(spread.n.add(spread.d), spread.d));

        volume = MoreMath.min(calcVolume(code, price), buyStock[code]);
    }

    function querySell(string calldata code)
        override
        external
        view
        returns (uint price, uint volume)
    {    
        ensureValidCode(code);

        PricingParameters memory p = parameters[code];

        price = calcPrice(p, Fraction(spread.d.sub(spread.n), spread.d));

        volume = MoreMath.min(calcVolume(code, price), sellStock[code]);
    }

    function buy(string calldata code, uint price, uint volume, address token) override external {

        ensureValidCode(code);

        // TODO: valdiate request and sell options to msg.sender
    }

    function sell(string calldata code, uint price, uint volume, address token) override external {

        ensureValidCode(code);

        // TODO: valdiate request and buy options from msg.sender
    }

    function ensureValidCode(string memory code) private view {

        require(parameters[code].udlFeed !=  address(0), "invalid code");
    }

    function calcPrice(PricingParameters memory p, Fraction memory f)
        private
        view
        returns (uint price)
    {
        UnderlyingFeed feed = UnderlyingFeed(p.udlFeed);
        (,int udlPrice) = feed.getLatestPrice();
        
        price = p.k1.add(
            uint(udlPrice).mul(p.k2.n).div(p.k2.d)
        ).add(
            feed.getDailyVolatility(p.timespan).mul(p.k3.n).div(p.k3.d)
        );

        price = price.mul(f.n).div(f.d);
    }

    function calcVolume(string memory code, uint price) private view returns (uint volume) {

        volume = exchange.calcSurplus(address(this)).mul(exchange.getVolumeBase()).div(price);
    }
}