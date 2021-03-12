pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../finance/OptionsExchange.sol";
import "../finance/RedeemableToken.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/LiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/ERC20.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract LinearLiquidityPool is LiquidityPool, ManagedContract, RedeemableToken {

    using SafeMath for uint;
    using SignedSafeMath for int;

    enum Operation { BUY, SELL }

    struct PricingParameters {
        address udlFeed;
        uint strike;
        uint maturity;
        OptionsExchange.OptionType optType;
        uint t0;
        uint t1;
        uint[] x;
        uint[] y;
        uint buyStock;
        uint sellStock;
    }

    TimeProvider private time;

    mapping(string => PricingParameters) private parameters;
    mapping(string => uint) private written;
    mapping(string => uint) private holding;

    address private owner;
    uint private spread;
    uint private reserveRatio;
    uint private maturity;

    uint private timeBase;
    uint private sqrtTimeBase;
    uint private volumeBase;
    uint private fractionBase;
    string[] private symbols;

    constructor(address deployer) public {

        Deployer(deployer).setContractAddress("LinearLiquidityPool");
    }

    function initialize(Deployer deployer) override internal {

        owner = deployer.getOwner();
        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));

        timeBase = 1e18;
        sqrtTimeBase = 1e9;
        volumeBase = exchange.getVolumeBase();
        fractionBase = 1e9;
    }

    function setParameters(
        uint _spread,
        uint _reserveRatio,
        uint _maturity
    )
        external
    {
        ensureCaller();
        spread = _spread;
        reserveRatio = _reserveRatio;
        maturity = _maturity;
    }

    function redeemAllowed() override public returns (bool) {
        
        return time.getNow() >= maturity;
    }

    function apy() override external view returns (uint) {

        return 0; // TODO: calculate pool APY
    }

    function addSymbol(
        string calldata symbol,
        address udlFeed,
        uint strike,
        uint _maturity,
        OptionsExchange.OptionType optType,
        uint t0,
        uint t1,
        uint[] calldata x,
        uint[] calldata y,
        uint buyStock,
        uint sellStock
    )
        external
    {
        ensureCaller();
        require(_maturity < maturity, "invalid maturity");
        require(x.length > 0 && x.length.mul(2) == y.length, "invalid pricing surface");

        if (parameters[symbol].x.length == 0) {
            symbols.push(symbol);
        }

        parameters[symbol] = PricingParameters(
            udlFeed,
            strike,
            _maturity,
            optType,
            t0,
            t1,
            x,
            y,
            buyStock,
            sellStock
        );

        emit AddSymbol(symbol);
    }
    
    function removeSymbol(string calldata symbol) external {

        ensureCaller();
        PricingParameters memory empty;
        parameters[symbol] = empty;
        delete written[symbol];
        delete holding[symbol];
        Arrays.removeItem(symbols, symbol);
        emit RemoveSymbol(symbol);
    }

    function depositTokens(address to, address token, uint value) override external {

        uint b0 = exchange.balanceOf(address(this));
        depositTokensInExchange(msg.sender, token, value);
        uint b1 = exchange.balanceOf(address(this));
        int expBal = exchange.calcExpectedPayout(address(this)).add(int(b1));

        uint ts = _totalSupply;
        uint p = b1.sub(b0).mul(fractionBase).div(uint(expBal));

        uint b = 1e3;
        uint v = ts > 0 ?
            ts.mul(p).mul(b).div(fractionBase.sub(p)) : 
            uint(expBal).mul(b);
        v = MoreMath.round(v, b);

        addBalance(to, v);
        _totalSupply = ts.add(v);
    }
    
    function listSymbols() override external returns (string memory available) {

        for (uint i = 0; i < symbols.length; i++) {
            if (parameters[symbols[i]].maturity > time.getNow()) {
                if (bytes(available).length == 0) {
                    available = symbols[i];
                } else {
                    available = string(abi.encodePacked(available, "\n", symbols[i]));
                }
            }
        }
    }

    function queryBuy(string memory symbol)
        override
        public
        view
        returns (uint price, uint volume)
    {
        ensureValidSymbol(symbol);
        PricingParameters memory param = parameters[symbol];
        price = calcOptPrice(param, Operation.BUY);
        volume = MoreMath.min(
            calcVolume(param, price, Operation.BUY),
            param.buyStock.sub(written[symbol])
        );
    }

    function querySell(string memory symbol)
        override
        public
        view
        returns (uint price, uint volume)
    {    
        ensureValidSymbol(symbol);
        PricingParameters memory param = parameters[symbol];
        price = calcOptPrice(param, Operation.SELL);
        volume = MoreMath.min(
            calcVolume(param, price, Operation.SELL),
            param.sellStock.sub(holding[symbol])
        );
    }

    function buy(string calldata symbol, uint price, uint volume, address token)
        override
        external
        returns (address addr)
    {
        ensureValidSymbol(symbol);

        PricingParameters memory param = parameters[symbol];
        uint p = calcOptPrice(param, Operation.BUY);
        require(price >= p, "insufficient price");

        uint value = p.mul(volume).div(volumeBase);
        depositTokensInExchange(msg.sender, token, value);

        uint _holding = holding[symbol];
        if (volume > _holding) {

            uint _written = written[symbol];
            uint toWrite = volume.sub(_holding);
            require(_written.add(toWrite) <= param.buyStock, "excessive volume");
            written[symbol] = _written.add(toWrite);

            exchange.writeOptions(
                param.udlFeed,
                toWrite,
                param.optType,
                param.strike,
                param.maturity
            );

            require(calcFreeBalance() > 0, "excessive volume");
        }

        if (_holding > 0) {
            uint diff = MoreMath.min(_holding, volume);
            holding[symbol] = _holding.sub(diff);
        }

        addr = exchange.resolveToken(symbol);
        OptionToken tk = OptionToken(addr);
        tk.transfer(msg.sender, volume);

        emit Buy(symbol, price, volume, token);
    }

    function sell(string calldata symbol, uint price, uint volume) override external {

        ensureValidSymbol(symbol);

        PricingParameters memory param = parameters[symbol];
        uint p = calcOptPrice(param, Operation.SELL);
        require(price <= p, "insufficient price");

        address addr = exchange.resolveToken(symbol);
        OptionToken tk = OptionToken(addr);
        tk.transferFrom(msg.sender, address(this), volume);

        uint value = p.mul(volume).div(volumeBase);
        exchange.transferBalance(msg.sender, value);
        require(calcFreeBalance() > 0, "excessive volume");
        
        uint _holding = holding[symbol].add(volume);
        uint _written = written[symbol];

        if (_written > 0) {
            uint toBurn = MoreMath.min(_written, volume);
            tk.burn(toBurn);
            written[symbol] = _written.sub(toBurn);
            _holding = _holding.sub(toBurn);
        }

        require(_holding <= param.sellStock, "excessive volume");
        holding[symbol] = _holding;

        emit Sell(symbol, price, volume);
    }

    function calcOptPrice(PricingParameters memory p, Operation op)
        private
        view
        returns (uint price)
    {
        uint f = op == Operation.BUY ? spread.add(fractionBase) : fractionBase.sub(spread);
        
        (uint j, uint xp) = findUdlPrice(p);

        uint _now = time.getNow();
        uint dt = p.t1.sub(p.t0);
        require(_now >= p.t0 && _now <= p.t1, "invalid pricing parameters");
        uint t = _now.sub(p.t0);
        uint p0 = calcOptPriceAt(p, 0, j, xp);
        uint p1 = calcOptPriceAt(p, p.x.length, j, xp);

        price = p0.mul(dt).sub(
            t.mul(p0.sub(p1))
        ).mul(f).div(fractionBase).div(dt);
    }

    function findUdlPrice(PricingParameters memory p) private view returns (uint j, uint xp) {

        UnderlyingFeed feed = UnderlyingFeed(p.udlFeed);
        (,int udlPrice) = feed.getLatestPrice();
        
        j = 0;
        xp = uint(udlPrice);
        while (p.x[j] < xp && j < p.x.length) {
            j++;
        }
        require(j > 0 && j < p.x.length, "invalid pricing parameters");
    }

    function calcOptPriceAt(
        PricingParameters memory p,
        uint offset,
        uint j,
        uint xp
    )
        private
        pure
        returns (uint price)
    {
        uint k = offset.add(j);
        price = p.y[k].sub(p.y[k - 1]).mul(
            xp.sub(p.x[j - 1])
        ).div(
            p.x[j].sub(p.x[j - 1])
        ).add(p.y[k - 1]);
    }

    function calcVolume(
        PricingParameters memory p,
        uint price,
        Operation op
    )
        private
        view
        returns (uint volume)
    {
        uint fb = calcFreeBalance();

        if (op == Operation.BUY) {

            uint coll = exchange.calcCollateral(
                p.udlFeed,
                volumeBase,
                p.optType,
                p.strike,
                p.maturity
            );

            volume = coll <= price ? uint(-1) :
                fb.mul(volumeBase).div(coll.sub(price));

        } else {
            
            uint iv = uint(exchange.calcIntrinsicValue(
                p.udlFeed,
                p.optType,
                p.strike,
                p.maturity
            ));

            volume = price <= iv ? uint(-1) :
                fb.mul(volumeBase).div(price.sub(iv));

            volume = MoreMath.min(
                volume, 
                exchange.balanceOf(address(this)).mul(volumeBase).div(price)
            );
        }
    }

    function calcFreeBalance() private view returns (uint balance) {

        balance = exchange.balanceOf(address(this)).mul(reserveRatio).div(fractionBase);
        uint sp = exchange.calcSurplus(address(this));
        balance = sp > balance ? sp.sub(balance) : 0;
    }

    function depositTokensInExchange(address sender, address token, uint value) private {

        ERC20 t = ERC20(token);
        t.transferFrom(sender, address(this), value);
        t.approve(address(exchange), value);
        exchange.depositTokens(address(this), token, value);
    }

    function addBalance(address _owner, uint value) override internal {

        if (balanceOf(_owner) == 0) {
            holders.push(_owner);
        }
        balances[_owner] = balanceOf(_owner).add(value);
    }

    function ensureValidSymbol(string memory symbol) private view {

        require(parameters[symbol].udlFeed !=  address(0), "invalid symbol");
    }

    function ensureCaller() private view {

        require(owner == address(0) || msg.sender == owner, "unauthorized caller");
    }
}