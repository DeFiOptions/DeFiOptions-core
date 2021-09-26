pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../finance/RedeemableToken.sol";
import "../finance/YieldTracker.sol";
import "../governance/ProtocolSettings.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/ILiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/ERC20.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeCast.sol";
import "../utils/SafeERC20.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

abstract contract LiquidityPool is ManagedContract, RedeemableToken, ILiquidityPool {

    using SafeCast for uint;
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using SignedSafeMath for int;

    enum Operation { NONE, BUY, SELL }

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

    struct Range {
        uint120 start;
        uint120 end;
    }

    TimeProvider private time;
    ProtocolSettings private settings;
    YieldTracker private tracker;

    mapping(string => PricingParameters) private parameters;
    mapping(string => mapping(uint => Range)) private ranges;

    uint internal spread;
    uint internal reserveRatio;
    uint public withdrawFee;
    uint public capacity;
    uint private _maturity;
    string[] private optSymbols;

    uint private timeBase;
    uint private sqrtTimeBase;
    uint internal volumeBase;
    uint internal fractionBase;

    constructor(string memory _name) ERC20(_name) public {
        
    }

    function initialize(Deployer deployer) virtual override internal {

        DOMAIN_SEPARATOR = ERC20(getImplementation()).DOMAIN_SEPARATOR();

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        tracker = YieldTracker(deployer.getContractAddress("YieldTracker"));

        timeBase = 1e18;
        sqrtTimeBase = 1e9;
        volumeBase = exchange.volumeBase();
        fractionBase = 1e9;
    }

    function setParameters(
        uint _spread,
        uint _reserveRatio,
        uint _withdrawFee,
        uint _capacity,
        uint _mt
    )
        external
    {
        ensureCaller();
        spread = _spread;
        reserveRatio = _reserveRatio;
        withdrawFee = _withdrawFee;
        capacity = _capacity;
        _maturity = _mt;
    }

    function redeemAllowed() override public view returns (bool) {
        
        return time.getNow() >= _maturity;
    }

    function maturity() override external view returns (uint) {
        
        return _maturity;
    }

    function yield(uint dt) override external view returns (uint y) {
        
        y = tracker.yield(address(this), dt);
    }

    function valueOf(address ownr) public view returns (uint) {

        (uint bal, int pOut) = getBalanceAndPayout();
        return uint(int(bal).add(pOut))
            .mul(balanceOf(ownr)).div(totalSupply());
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
    
    function setRange(string calldata optSymbol, Operation op, uint start, uint end) external {

        ensureCaller();
        ranges[optSymbol][uint(op)] = Range(start.toUint120(), end.toUint120());
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
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
        depositTokens(to, token, value);
    }

    function depositTokens(address to, address token, uint value) override public {

        (uint b0, int po) = getBalanceAndPayout();
        depositTokensInExchange(token, value);
        uint b1 = exchange.balanceOf(address(this));
        require(b1 <= capacity, "capacity exceeded");
        
        tracker.push(int(b0).add(po), b1.sub(b0).toInt256());

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

    function withdraw(uint amount) override external {

        uint bal = balanceOf(msg.sender);
        require(bal >= amount, "insufficient caller balance");

        uint val = valueOf(msg.sender).mul(amount).div(bal);
        uint discountedValue = val.mul(fractionBase.sub(withdrawFee)).div(fractionBase);
        require(discountedValue <= calcFreeBalance(), "insufficient pool balance");

        (uint b0, int po) = getBalanceAndPayout();
        exchange.transferBalance(address(this), msg.sender, discountedValue);
        tracker.push(int(b0).add(po), -(val.toInt256()));
        
        removeBalance(msg.sender, amount);
        emitTransfer(msg.sender, address(0), amount);
    }

    function calcFreeBalance() public view returns (uint balance) {

        uint exBal = exchange.balanceOf(address(this));
        uint reserve = exBal.mul(reserveRatio).div(fractionBase);
        uint sp = exBal.sub(exchange.collateral(address(this)));
        balance = sp > reserve ? sp.sub(reserve) : 0;
    }

    function listSymbols() override external view returns (string memory available) {

        available = listSymbols(Operation.BUY);
    }

    function listSymbols(Operation op) public view returns (string memory available) {

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

    function isAvailable(string memory optSymbol, Operation op) public view returns (bool b) {

        b = true;

        PricingParameters memory param = parameters[optSymbol];

        if (param.maturity <= time.getNow()) {
            
            b = false;

        } else if (op == Operation.BUY || op == Operation.SELL) {

            if (!isInRange(optSymbol, op, param.udlFeed)) {
                b = false;
            } else {
                b = getAvailableStock(optSymbol, param, op) > 0;
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
        string calldata optSymbol,
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
        external
        returns (address _tk)
    {        
        IERC20Permit(token).permit(msg.sender, address(this), maxValue, deadline, v, r, s);
        _tk = buy(optSymbol, price, volume, token);
    }

    function buy(string memory optSymbol, uint price, uint volume, address token)
        override
        public
        returns (address _tk)
    {
        require(volume > 0, "invalid volume");
        ensureValidSymbol(optSymbol);

        PricingParameters memory param = parameters[optSymbol];

        require(isInRange(optSymbol, Operation.BUY, param.udlFeed), "out of range");

        price = receivePayment(param, price, volume, token);

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
        
        require(isInRange(optSymbol, Operation.SELL, param.udlFeed), "out of range");

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

    function writeOptions(
        OptionToken tk,
        PricingParameters memory param,
        uint volume,
        address to
    )
        virtual
        internal;

    function calcOptPrice(PricingParameters memory p, Operation op)
        virtual
        internal
        view
        returns (uint price);

    function calcVolume(
        string memory optSymbol,
        PricingParameters memory p,
        uint price,
        Operation op
    )
        virtual
        internal
        view
        returns (uint volume);

    function getUdlPrice(address udlFeed) internal view returns (int udlPrice) {

        UnderlyingFeed feed = UnderlyingFeed(udlFeed);
        (, udlPrice) = feed.getLatestPrice();
    }

    function getBalanceAndPayout() private view returns (uint bal, int pOut) {
        
        bal = exchange.balanceOf(address(this));
        pOut = exchange.calcExpectedPayout(address(this));
    }

    function isInRange(
        string memory optSymbol,
        Operation op,
        address udlFeed
    )
        private
        view
        returns(bool)
    {
        Range memory r = ranges[optSymbol][uint(op)];
        if (r.start == 0 && r.end == 0) {
            return true;
        }
        int udlPrice = getUdlPrice(udlFeed);
        return uint(udlPrice) >= r.start && uint(udlPrice) <= r.end;
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
        address token
    )
        private
        returns (uint)
    {
        price = validatePrice(price, param, Operation.BUY);
        uint value = price.mul(volume).div(volumeBase);

        if (token != address(exchange)) {
            (uint tv, uint tb) = settings.getTokenRate(token);
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

    function depositTokensInExchange(address token, uint value) private {
        
        IERC20 t = IERC20(token);
        t.safeTransferFrom(msg.sender, address(this), value);
        t.safeApprove(address(exchange), value);
        exchange.depositTokens(address(this), token, value);
    }

    function ensureValidSymbol(string memory optSymbol) private view {

        require(parameters[optSymbol].udlFeed !=  address(0), "invalid optSymbol");
    }

    function ensureCaller() private view {

        require(msg.sender == getOwner(), "unauthorized caller");
    }
}