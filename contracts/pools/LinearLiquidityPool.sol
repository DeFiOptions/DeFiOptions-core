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
        uint strike;
        uint maturity;
        OptionsExchange.OptionType optType;
        uint[] x;
        uint[] y;
    }

    TimeProvider private time;
    OptionsExchange private exchange;

    mapping(string => PricingParameters) private parameters;
    mapping(string => uint) private buyStock;
    mapping(string => uint) private sellStock;

    address private owner;
    Fraction private spread;
    Fraction private ratio;

    uint timeBase = 1e18;
    uint sqrtTimeBase = 1e9;

    constructor(
        address _time,
        address _exchange
    ) public {

        owner = tx.origin;
        time = TimeProvider(_time);
        exchange = OptionsExchange(_exchange);
        spread = Fraction(500, 10000); //  5 %
        ratio = Fraction(2000, 10000); // 20 %
    }

    function addCode(
        string calldata code,
        address udlFeed,
        uint strike,
        uint maturity,
        OptionsExchange.OptionType optType,
        uint[] calldata x,
        uint[] calldata y
    )
        external
    {
        ensureCaller();
        parameters[code] = PricingParameters(udlFeed, strike, maturity, optType, x, y);
        emit AddCode(code);
    }
    
    function removeCode(string calldata code) external {

        ensureCaller();
        PricingParameters memory empty;
        parameters[code] = empty;
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

        PricingParameters memory param = parameters[code];
        uint id = exchange.writeOptions(
            param.udlFeed,
            volume,
            param.optType,
            param.strike,
            param.maturity
        );
        address addr = exchange.resolveToken(id);
        OptionToken tk = OptionToken(addr);
        tk.transfer(msg.sender, volume);
    }

    function sell(string calldata code, uint price, uint volume) override external {

        ensureValidCode(code);

        (uint p, uint v) = querySell(code);
        require(price <= p, "insufficient price");
        require(volume <= v, "excessive volume");

        uint value = p.mul(volume).div(exchange.getVolumeBase());
        exchange.transferBalance(msg.sender, value);

        address addr = exchange.resolveToken(code);
        OptionToken tk = OptionToken(addr);
        tk.transferFrom(msg.sender, address(this), volume);
    }

    function calcPrice(PricingParameters memory p, Fraction memory f)
        private
        view
        returns (uint price)
    {
        UnderlyingFeed feed = UnderlyingFeed(p.udlFeed);
        (,int udlPrice) = feed.getLatestPrice();
        
        uint i = 0;
        uint xp = uint(udlPrice);
        while (p.x[i] < xp && i < p.x.length) {
            i++;
        }
        require(i > 0 && i < p.x.length, "invalid pricing parameters");

        price = p.y[i].sub(p.y[i - 1]).mul(
            xp.sub(p.x[i - 1])
        ).div(
            p.x[i].sub(p.x[i - 1])
        ).add(p.y[i - 1]);

        price = price.mul(f.n).div(f.d);
    }

    function calcVolume(uint price) private view returns (uint volume) {

        // TODO: review volume calculation considering collateral requirements

        uint bal = exchange.balanceOf(address(this)).mul(ratio.n).div(ratio.d);
        bal = exchange.calcSurplus(address(this)).sub(bal);
        volume = bal.mul(exchange.getVolumeBase()).div(price);
    }

    function depositTokensInExchange(address to, address token, uint value) private {

        ERC20 t = ERC20(token);
        t.transferFrom(msg.sender, address(this), value);
        t.approve(address(exchange), value);
        exchange.depositTokens(to, token, value);
    }

    function ensureValidCode(string memory code) private view {

        require(parameters[code].udlFeed !=  address(0), "invalid code");
    }

    function ensureCaller() private view {

        require(msg.sender == owner, "unauthorized caller");
    }
}