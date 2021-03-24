pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../finance/OptionsExchange.sol";
import "../finance/RedeemableToken.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/LiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/ERC20.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeCast.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract LinearLiquidityPool is LiquidityPool, ManagedContract, RedeemableToken {

    using SafeCast for uint;
    using SafeMath for uint;
    using SignedSafeMath for int;

    enum Operation { BUY, SELL }

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

    mapping(string => PricingParameters) private parameters;
    mapping(string => uint120) private written;
    mapping(string => uint120) private holding;

    string private constant _name = "Linear Liquidity Pool Redeemable Token";
    string private constant _symbol = "LLPTK";

    address private owner;
    uint private spread;
    uint private reserveRatio;
    uint private _maturity;

    uint private timeBase;
    uint private sqrtTimeBase;
    uint private volumeBase;
    uint private fractionBase;
    string[] private optSymbols;
    Deposit[] private deposits;

    constructor(address deployer) ERC20(_name) public {

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

    function redeemAllowed() override public returns (bool) {
        
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
        string calldata optSymbol,
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
        delete written[optSymbol];
        delete holding[optSymbol];
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
        depositTokensInExchange(msg.sender, token, value);
        uint b1 = exchange.balanceOf(address(this));
        int po = exchange.calcExpectedPayout(address(this));
        
        deposits.push(Deposit(time.getNow().toUint32(), uint(int(b0).add(po)), value));

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
    
    function listSymbols() override external view returns (string memory available) {

        for (uint i = 0; i < optSymbols.length; i++) {
            if (parameters[optSymbols[i]].maturity > time.getNow()) {
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
            calcVolume(param, price, Operation.BUY),
            uint(param.buyStock).sub(written[optSymbol])
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
            calcVolume(param, price, Operation.SELL),
            uint(param.sellStock).sub(holding[optSymbol])
        );
    }
    
    function buy(
        string calldata optSymbol,
        uint price,
        uint volume,
        address token,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        override
        external
        returns (address addr)
    {
        uint value = price.mul(volume).div(volumeBase);
        ERC20(token).permit(msg.sender, address(this), value, deadline, v, r, s);
        addr = buy(optSymbol, price, volume, token);
    }

    function buy(string memory optSymbol, uint price, uint volume, address token)
        override
        public
        returns (address addr)
    {
        require(volume > 0, "invalid volume");
        ensureValidSymbol(optSymbol);

        PricingParameters memory param = parameters[optSymbol];
        price = validatePrice(price, param, Operation.BUY);

        uint value = price.mul(volume).div(volumeBase);
        depositTokensInExchange(msg.sender, token, value);

        uint _holding = holding[optSymbol];
        if (volume > _holding) {

            uint _written = written[optSymbol];
            uint toWrite = volume.sub(_holding);
            require(_written.add(toWrite) <= param.buyStock, "excessive volume");
            written[optSymbol] = _written.add(toWrite).toUint120();

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
            holding[optSymbol] = _holding.sub(diff).toUint120();
        }

        addr = exchange.resolveToken(optSymbol);
        OptionToken tk = OptionToken(addr);
        tk.transfer(msg.sender, volume);

        emit Buy(optSymbol, price, volume, token);
    }

    function sell(string calldata optSymbol, uint price, uint volume) override external {
        
        require(volume > 0, "invalid volume");
        ensureValidSymbol(optSymbol);

        PricingParameters memory param = parameters[optSymbol];
        price = validatePrice(price, param, Operation.SELL);

        address addr = exchange.resolveToken(optSymbol);
        OptionToken tk = OptionToken(addr);
        tk.transferFrom(msg.sender, address(this), volume);

        uint value = price.mul(volume).div(volumeBase);
        exchange.transferBalance(msg.sender, value);
        require(calcFreeBalance() > 0, "excessive volume");
        
        uint _holding = uint(holding[optSymbol]).add(volume);
        uint _written = written[optSymbol];

        if (_written > 0) {
            uint toBurn = MoreMath.min(_written, volume);
            tk.burn(toBurn);
            written[optSymbol] = _written.sub(toBurn).toUint120();
            _holding = _holding.sub(toBurn);
        }

        require(_holding <= param.sellStock, "excessive volume");
        holding[optSymbol] = _holding.toUint120();

        emit Sell(optSymbol, price, volume);
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

    function calcOptPrice(PricingParameters memory p, Operation op)
        private
        view
        returns (uint price)
    {
        uint f = op == Operation.BUY ? spread.add(fractionBase) : fractionBase.sub(spread);
        
        (uint j, uint xp) = findUdlPrice(p);

        uint _now = time.getNow();
        uint dt = uint(p.t1).sub(uint(p.t0));
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
        int yA = int(p.y[k]);
        int yB = int(p.y[k - 1]);
        price = uint(
            yA.sub(yB).mul(
                int(xp.sub(p.x[j - 1]))
            ).div(
                int(p.x[j]).sub(int(p.x[j - 1]))
            ).add(yB)
        );
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

    function ensureValidSymbol(string memory optSymbol) private view {

        require(parameters[optSymbol].udlFeed !=  address(0), "invalid optSymbol");
    }

    function ensureCaller() private view {

        require(owner == address(0) || msg.sender == owner, "unauthorized caller");
    }
}