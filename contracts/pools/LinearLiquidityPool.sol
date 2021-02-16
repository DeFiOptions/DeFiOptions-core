pragma solidity >=0.6.0;

import "../finance/OptionsExchange.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/LiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/ERC20.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract LinearLiquidityPool is LiquidityPool, ERC20 {

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
    Fraction private ratio;

    constructor(
        address _time,
        address _exchange
    ) public {

        time = TimeProvider(_time);
        exchange = OptionsExchange(_exchange);
        spread = Fraction(1000, 10000); // 10 %
        ratio = Fraction(2000, 10000);  // 20 %
    }

    function addCode(string calldata code) external {

        // TODO: register tradable option and pricing model parameters
        emit AddCode(code);
    }
    
    function removeCode(string calldata code) external {

        // TODO: remove tradable option
        emit RemoveCode(code);
    }

    function depositTokens(address to, address token, uint value) override external {

        uint b0 = exchange.balanceOf(to);
        depositTokensInExchange(address(this), token, value);
        uint b1 = exchange.balanceOf(to);
        addBalance(to, b1.sub(b0));
    }

    function queryBuy(string memory code)
        override
        public
        view
        returns (uint price, uint volume)
    {
        ensureValidCode(code);
        PricingParameters memory p = parameters[code];
        price = calcPrice(p, Fraction(spread.n.add(spread.d), spread.d));
        volume = MoreMath.min(calcVolume(price), buyStock[code]);
    }

    function querySell(string memory code)
        override
        public
        view
        returns (uint price, uint volume)
    {    
        ensureValidCode(code);
        PricingParameters memory p = parameters[code];
        price = calcPrice(p, Fraction(spread.d.sub(spread.n), spread.d));
        volume = MoreMath.min(calcVolume(price), sellStock[code]);
    }

    function buy(string calldata code, uint price, uint volume, address token) override external {

        ensureValidCode(code);

        (uint p, uint v) = queryBuy(code);
        require(price >= p, "insufficient price");
        require(volume <= v, "excessive volume");

        uint value = p.mul(volume).div(exchange.getVolumeBase());
        depositTokensInExchange(address(this), token, value);

        // TODO: write and transfer option tokens
    }

    function sell(string calldata code, uint price, uint volume) override external {

        ensureValidCode(code);

        (uint p, uint v) = querySell(code);
        require(price <= p, "insufficient price");
        require(volume <= v, "excessive volume");

        uint value = p.mul(volume).div(exchange.getVolumeBase());
        exchange.transferBalance(msg.sender, value);

        // TODO: acquire option tokens
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

    function calcVolume(uint price) private view returns (uint volume) {

        uint bal = exchange.balanceOf(address(this)).mul(ratio.n).div(ratio.d);
        bal = exchange.calcSurplus(address(this)).sub(bal);
        volume = bal.mul(exchange.getVolumeBase()).div(price);

        // TODO: review volume calculation considering collateral requirements
    }

    function depositTokensInExchange(address to, address token, uint value) private {

        ERC20 t = ERC20(token);
        t.transferFrom(msg.sender, address(this), value);
        t.approve(address(exchange), value);
        exchange.depositTokens(to, token, value);
    }
}