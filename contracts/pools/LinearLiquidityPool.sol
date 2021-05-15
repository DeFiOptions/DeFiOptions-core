pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../finance/RedeemableToken.sol";
import "../governance/ProtocolSettings.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/LiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/ERC20.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeCast.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./LinearInterpolator.sol";

contract LinearLiquidityPool is LiquidityPool, ManagedContract, RedeemableToken {

    using SafeCast for uint;
    using SafeMath for uint;
    using SignedSafeMath for int;

    struct PricingParameters {
        address udlFeed;
        OptionsExchange.OptionType optType;
        uint120 strike;
        uint32 maturity;
        uint32 t0;
        uint32 t1;
        uint120 buyStock;
        uint120 sellStock;
        uint120[] x;
        uint120[] y;
    }

    struct Deposit {
        uint32 date;
        uint balance;
        uint value;
    }

    TimeProvider private time;
    ProtocolSettings private settings;
    CreditProvider private creditProvider;
    LinearInterpolator private interpolator;

    mapping(string => PricingParameters) private parameters;

    string private constant _name = "Linear Liquidity Pool Redeemable Token";
    string private constant _symbol = "LLPTK";

    address private owner;
    uint private spread;
    uint private reserveRatio;
    uint private _maturity;
    string[] private optSymbols;
    Deposit[] private deposits;

    uint private timeBase;
    uint private sqrtTimeBase;
    uint private volumeBase;
    uint private fractionBase;

    constructor() ERC20(_name) public {
        
    }

    function initialize(Deployer deployer) override internal {

        DOMAIN_SEPARATOR = ERC20(getImplementation()).DOMAIN_SEPARATOR();

        owner = deployer.getOwner();
        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        interpolator = LinearInterpolator(deployer.getContractAddress("LinearInterpolator"));

        timeBase = 1e18;
        sqrtTimeBase = 1e9;
        volumeBase = exchange.volumeBase();
        fractionBase = 1e9;
    }

    function name() override external view returns (string memory) {
        return _name;
    }

    function symbol() override external view returns (string memory) {
        return _symbol;
    }

    function setParameters(
        uint _spread,
        uint _reserveRatio,
        uint _mt
    )
        external
    {
        ensureCaller();
        spread = _spread;
        reserveRatio = _reserveRatio;
        _maturity = _mt;
    }

    function redeemAllowed() override public view returns (bool) {
        
        return time.getNow() >= _maturity;
    }

    function maturity() override external view returns (uint) {
        
        return _maturity;
    }

    function yield(uint dt) override external view returns (uint y) {
        
        y = fractionBase;

        if (deposits.length > 0) {
            
            uint _now = time.getNow();
            uint start = _now.sub(dt);
            
            uint i = 0;
            for (i = 0; i < deposits.length; i++) {
                if (deposits[i].date > start) {
                    break;
                }
            }

            for (; i <= deposits.length; i++) {
                if (i > 0) {
                    y = y.mul(calcYield(i, start)).div(fractionBase);
                }
            }
        }
    }

    function addSymbol(
        address udlFeed,
        uint strike,
        uint _mt,
        OptionsExchange.OptionType optType,
        uint t0,
        uint t1,
        uint120[] calldata x,
        uint120[] calldata y,
        uint buyStock,
        uint sellStock
    )
        external
    {
        ensureCaller();
        require(_mt < _maturity, "invalid maturity");
        require(x.length > 0 && x.length.mul(2) == y.length, "invalid pricing surface");

        string memory optSymbol = exchange.getOptionSymbol(
            udlFeed,
            optType,
            strike,
            _mt
        );

        if (parameters[optSymbol].x.length == 0) {
            optSymbols.push(optSymbol);
        }

        parameters[optSymbol] = PricingParameters(
            udlFeed,
            optType,
            strike.toUint120(),
            _mt.toUint32(),
            t0.toUint32(),
            t1.toUint32(),
            buyStock.toUint120(),
            sellStock.toUint120(),
            x,
            y
        );

        emit AddSymbol(optSymbol);
    }
    
    function removeSymbol(string calldata optSymbol) external {

        ensureCaller();
        PricingParameters memory empty;
        parameters[optSymbol] = empty;
        Arrays.removeItem(optSymbols, optSymbol);
        emit RemoveSymbol(optSymbol);
    }

    function depositTokens(
        address to,
        address token,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        override
        external
    {
        ERC20(token).permit(msg.sender, address(this), value, deadline, v, r, s);
        depositTokens(to, token, value);
    }

    function depositTokens(address to, address token, uint value) override public {

        uint b0 = exchange.balanceOf(address(this));
        depositTokensInExchange(token, value);
        uint b1 = exchange.balanceOf(address(this));
        int po = exchange.calcExpectedPayout(address(this));
        
        deposits.push(
            Deposit(time.getNow().toUint32(), uint(int(b0).add(po)), b1.sub(b0))
        );

        uint ts = _totalSupply;
        int expBal = po.add(int(b1));
        uint p = b1.sub(b0).mul(fractionBase).div(uint(expBal));

        uint b = 1e3;
        uint v = ts > 0 ?
            ts.mul(p).mul(b).div(fractionBase.sub(p)) : 
            uint(expBal).mul(b);
        v = MoreMath.round(v, b);

        addBalance(to, v);
        _totalSupply = ts.add(v);
        emitTransfer(address(0), to, v);
    }

    function calcFreeBalance() public view returns (uint balance) {

        uint exBal = exchange.balanceOf(address(this));
        uint reserve = exBal.mul(reserveRatio).div(fractionBase);
        uint sp = exBal.sub(exchange.collateral(address(this)));
        balance = sp > reserve ? sp.sub(reserve) : 0;
    }

    function listSymbols(Operation op) override public view returns (string memory available) {

        for (uint i = 0; i < optSymbols.length; i++) {
            if (isAvailable(optSymbols[i], op)) {
                if (bytes(available).length == 0) {
                    available = optSymbols[i];
                } else {
                    available = string(abi.encodePacked(available, "\n", optSymbols[i]));
                }
            }
        }
    }

    function queryBuy(string memory optSymbol)
        override
        public
        view
        returns (uint price, uint volume)
    {
        ensureValidSymbol(optSymbol);
        PricingParameters memory param = parameters[optSymbol];
        price = calcOptPrice(param, Operation.BUY);
        volume = MoreMath.min(
            calcVolume(optSymbol, param, price, Operation.BUY),
            getAvailableStock(optSymbol, param, Operation.BUY)
        );
    }

    function querySell(string memory optSymbol)
        override
        public
        view
        returns (uint price, uint volume)
    {    
        ensureValidSymbol(optSymbol);
        PricingParameters memory param = parameters[optSymbol];
        price = calcOptPrice(param, Operation.SELL);
        volume = MoreMath.min(
            calcVolume(optSymbol, param, price, Operation.SELL),
            getAvailableStock(optSymbol, param, Operation.SELL)
        );
    }
    
    function buy(
        string memory optSymbol,
        uint price,
        uint volume,
        address token,
        uint maxValue,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        override
        public
        returns (address _tk)
    {
        require(volume > 0, "invalid volume");
        ensureValidSymbol(optSymbol);

        PricingParameters memory param = parameters[optSymbol];
        price = receivePayment(param, price, volume, maxValue, token, deadline, v, r, s);

        _tk = exchange.resolveToken(optSymbol);
        OptionToken tk = OptionToken(_tk);
        uint _holding = tk.balanceOf(address(this));

        if (volume > _holding) {
            writeOptions(tk, param, volume, msg.sender);
        } else {
            tk.transfer(msg.sender, volume);
        }

        emit Buy(_tk, msg.sender, price, volume);
    }

    function buy(string calldata optSymbol, uint price, uint volume, address token)
        override
        external
        returns (address _tk)
    {
        bytes32 x;
        uint maxValue = price.mul(volume).div(volumeBase);
        _tk = buy(optSymbol, price, volume, token, maxValue, 0, 0, x, x);
    }

    function sell(
        string memory optSymbol,
        uint price,
        uint volume,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        override
        public
    {
        require(volume > 0, "invalid volume");
        ensureValidSymbol(optSymbol);

        PricingParameters memory param = parameters[optSymbol];
        price = validatePrice(price, param, Operation.SELL);

        address _tk = exchange.resolveToken(optSymbol);
        OptionToken tk = OptionToken(_tk);
        if (deadline > 0) {
            tk.permit(msg.sender, address(this), volume, deadline, v, r, s);
        }
        tk.transferFrom(msg.sender, address(this), volume);
        
        uint _written = tk.writtenVolume(address(this));
        if (_written > 0) {
            uint toBurn = MoreMath.min(_written, volume);
            tk.burn(toBurn);
        }

        uint value = price.mul(volume).div(volumeBase);
        exchange.transferBalance(msg.sender, value);
        
        require(calcFreeBalance() > 0, "pool balance too low");

        uint _holding = tk.balanceOf(address(this));
        require(_holding <= param.sellStock, "excessive volume");

        emit Sell(_tk, msg.sender, price, volume);
    }

    function sell(string calldata optSymbol, uint price, uint volume) override external {
        
        bytes32 x;
        sell(optSymbol, price, volume, 0, 0, x, x);
    }

    function isAvailable(string memory optSymbol, Operation op) private view returns (bool b) {

        b = true;

        PricingParameters memory param = parameters[optSymbol];

        if (param.maturity <= time.getNow()) {
            
            b = false;

        } else if (op == Operation.BUY || op == Operation.SELL) {

            UnderlyingFeed feed = UnderlyingFeed(param.udlFeed);
            (,int udlPrice) = feed.getLatestPrice();

            if (udlPrice < param.x[0] || udlPrice > param.x[param.x.length - 1]) {
                b = false;
            } else {
                b = getAvailableStock(optSymbol, param, op) > 0;
            }
        }
    }

    function getAvailableStock(
        string memory optSymbol,
        PricingParameters memory param,
        Operation op
    )
        private
        view
        returns (uint)
    {    
        uint stock = 0;
        uint bal = 0;
        OptionToken tk = OptionToken(
            exchange.resolveToken(optSymbol)
        );
        if (op == Operation.BUY) {
            stock = uint(param.buyStock);
            bal = tk.writtenVolume(address(this));
        } else {
            stock = uint(param.sellStock);
            bal = tk.balanceOf(address(this));
        }
        return stock > bal ? stock - bal : 0;
    }

    function receivePayment(
        PricingParameters memory param,
        uint price,
        uint volume,
        uint maxValue,
        address token,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        private
        returns (uint)
    {
        price = validatePrice(price, param, Operation.BUY);
        uint value = price.mul(volume).div(volumeBase);

        if (token != address(exchange)) {
            (uint tv, uint tb) = settings.getTokenRate(token);
            if (deadline > 0) {
                ERC20(token).permit(msg.sender, address(this), maxValue, deadline, v, r, s);
            }
            value = value.mul(tv).div(tb);
            depositTokensInExchange(token, value);
        } else {
            exchange.transferBalance(msg.sender, address(this), value);
        }

        return price;
    }

    function validatePrice(
        uint price, 
        PricingParameters memory param, 
        Operation op
    ) 
        private
        view
        returns (uint p) 
    {
        p = calcOptPrice(param, op);
        require(
            op == Operation.BUY ? price >= p : price <= p,
            "insufficient price"
        );
    }

    function writeOptions(
        OptionToken tk,
        PricingParameters memory param,
        uint volume,
        address to
    )
        private
    {
        uint _written = tk.writtenVolume(address(this));
        require(_written.add(volume) <= param.buyStock, "excessive volume");

        exchange.writeOptions(
            param.udlFeed,
            volume,
            param.optType,
            param.strike,
            param.maturity,
            to
        );
        
        require(calcFreeBalance() > 0, "pool balance too low");
    }

    function calcOptPrice(PricingParameters memory p, Operation op)
        private
        view
        returns (uint price)
    {
        uint f = op == Operation.BUY ? spread.add(fractionBase) : fractionBase.sub(spread);
        price = interpolator.interpolate(p.udlFeed, p.t0, p.t1, p.x, p.y, f);
    }

    function calcVolume(
        string memory optSymbol,
        PricingParameters memory p,
        uint price,
        Operation op
    )
        private
        view
        returns (uint volume)
    {
        uint fb = calcFreeBalance();
        uint r = fractionBase.sub(reserveRatio);

        uint coll = exchange.calcCollateral(
            p.udlFeed,
            volumeBase,
            p.optType,
            p.strike,
            p.maturity
        );

        if (op == Operation.BUY) {

            volume = coll <= price ? uint(-1) :
                fb.mul(volumeBase).div(
                    coll.sub(price.mul(r).div(fractionBase))
                );

        } else {

            uint bal = exchange.balanceOf(address(this));

            uint poolColl = exchange.collateral(address(this));

            uint writtenColl = OptionToken(
                exchange.resolveToken(optSymbol)
            ).writtenVolume(address(this)).mul(coll);

            poolColl = poolColl > writtenColl ? poolColl.sub(writtenColl) : 0;
            
            uint iv = uint(exchange.calcIntrinsicValue(
                p.udlFeed,
                p.optType,
                p.strike,
                p.maturity
            ));

            volume = price <= iv ? uint(-1) :
                bal.sub(poolColl.mul(fractionBase).div(r)).mul(volumeBase).div(
                    price.sub(iv)
                );

            volume = MoreMath.max(
                volume, 
                bal.mul(volumeBase).div(price)
            );

            volume = MoreMath.min(
                volume, 
                bal.mul(volumeBase).div(price)
            );
        }
    }

    function calcYield(uint index, uint start) private view returns (uint y) {

        uint t0 = deposits[index - 1].date;
        uint t1 = index < deposits.length ?
            deposits[index].date : time.getNow();

        int v0 = int(deposits[index - 1].value.add(deposits[index - 1].balance));
        int v1 = index < deposits.length ? 
            int(deposits[index].balance) :
            exchange.calcExpectedPayout(address(this)).add(int(exchange.balanceOf(address(this))));

        y = uint(v1.mul(int(fractionBase)).div(v0));
        if (start > t0) {
            y = MoreMath.powDecimal(
                y, 
                (t1.sub(start)).mul(fractionBase).div(t1.sub(t0)), 
                fractionBase
            );
        }
    }

    function depositTokensInExchange(address token, uint value) private {
        
        ERC20 t = ERC20(token);
        t.transferFrom(msg.sender, address(creditProvider), value);
        creditProvider.addBalance(address(this), token, value);
    }

    function ensureValidSymbol(string memory optSymbol) private view {

        require(parameters[optSymbol].udlFeed !=  address(0), "invalid optSymbol");
    }

    function ensureCaller() private view {

        require(owner == address(0) || msg.sender == owner, "unauthorized caller");
    }
}