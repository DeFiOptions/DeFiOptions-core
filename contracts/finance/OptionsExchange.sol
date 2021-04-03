pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../governance/ProtocolSettings.sol";
import "../utils/ERC20.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/Arrays.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeCast.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./CreditProvider.sol";
import "./OptionToken.sol";
import "./OptionTokenFactory.sol";

contract OptionsExchange is ManagedContract {

    using SafeCast for uint;
    using SafeMath for uint;
    using SignedSafeMath for int;
    
    enum OptionType { CALL, PUT }
    
    struct OptionData {
        uint48 id;
        address udlFeed;
        OptionType _type;
        uint120 strike;
        uint32 maturity;
    }

    struct FeedData {
        uint120 lowerVol;
        uint120 upperVol;
    }
    
    struct OrderData {
        uint48 id;
        uint48 optId;
        address owner;
        uint120 written;
        uint120 holding;
    }
    
    TimeProvider private time;
    ProtocolSettings private settings;
    CreditProvider private creditProvider;
    OptionTokenFactory private factory;

    mapping(uint => OptionData) private options;
    mapping(address => FeedData) private feeds;
    mapping(uint => OrderData) private orders;
    mapping(address => uint48[]) private book;
    mapping(string => uint48) private optIndex;
    mapping(address => mapping(string => uint48)) private ordIndex;
    mapping(address => uint256) public collateral;

    mapping(string => address) private tokenAddress;
    mapping(string => uint48[]) private tokenIds;

    mapping(address => uint) public nonces;
    
    uint48 private serial;
    uint private volumeBase;
    uint private timeBase;
    uint private sqrtTimeBase;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    event CreateSymbol(address indexed token, address indexed issuer);

    event WriteOptions(address indexed token, address indexed issuer, uint volume, uint id);

    event LiquidateEarly(address indexed token, address indexed sender, uint volume);

    event LiquidateExpired(address indexed token, address indexed sender, uint volume);

    constructor(address deployer) public {

        string memory _name = "OptionsExchange";
        Deployer(deployer).setContractAddress(_name);

        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(_name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        factory = OptionTokenFactory(deployer.getContractAddress("OptionTokenFactory"));

        serial = 1;
        volumeBase = 1e18;
        timeBase = 1e18;
        sqrtTimeBase = 1e9;
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
        external
    {
        ERC20(token).permit(msg.sender, address(this), value, deadline, v, r, s);
        depositTokens(to, token, value);
    }

    function depositTokens(address to, address token, uint value) public {

        ERC20 t = ERC20(token);
        t.transferFrom(msg.sender, address(creditProvider), value);
        creditProvider.addBalance(to, token, value);
    }

    function balanceOf(address owner) external view returns (uint) {

        return creditProvider.balanceOf(owner);
    }

    function transferBalance(
        address from, 
        address to, 
        uint value,
        uint maxValue,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        require(maxValue >= value, "insufficient permit value");
        permit(from, to, maxValue, deadline, v, r, s);
        creditProvider.transferBalance(from, to, value);
        ensureFunds(from);
    }

    function transferBalance(address to, uint value) public {

        creditProvider.transferBalance(msg.sender, to, value);
        ensureFunds(msg.sender);
    }
    
    function withdrawTokens(uint value) external {
        
        require(value <= calcSurplus(msg.sender), "insufficient surplus");
        creditProvider.withdrawTokens(msg.sender, value);
    }

    function writeOptions(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        external 
        returns (uint id, address tk)
    {
        (id, tk) = createOrder(udlFeed, volume, optType, strike, maturity, msg.sender);
        ensureFunds(msg.sender);
    }

    function writeOptions(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity,
        address to
    )
        external 
        returns (uint id, address tk)
    {
        (id, tk) = createOrder(udlFeed, volume, optType, strike, maturity, to);
        if (to != msg.sender) {
            transferOwnershipInternal(OptionToken(tk).symbol(), msg.sender, to, volume);
        } else {
            ensureFunds(msg.sender);
        }
    }

    function writtenVolume(string calldata symbol, address owner) external view returns (uint) {

        return uint(findOrder(owner, symbol).written);
    }

    function transferOwnership(
        string calldata symbol,
        address from,
        address to,
        uint volume
    )
        external
    {
        require(tokenAddress[symbol] == msg.sender, "unauthorized ownership transfer");
        transferOwnershipInternal(symbol, from, to, volume);
    }

    function burnOptions(
        string calldata symbol,
        address owner,
        uint volume
    )
        external
    {
        require(tokenAddress[symbol] == msg.sender, "unauthorized burn");
        
        OrderData memory ord = findOrder(owner, symbol);
        
        require(isValid(ord), "order not found");
        require(ord.written >= volume && ord.holding >= volume, "invalid volume");
        
        uint120 _written = uint(ord.written).sub(volume).toUint120();
        orders[ord.id].written = _written;
        uint120 _holding = uint(ord.holding).sub(volume).toUint120();
        orders[ord.id].holding = _holding;

        if (shouldRemove(_written, _holding)) {
            removeOrder(symbol, ord);
        }
    }

    function liquidateSymbol(string calldata symbol, uint limit) external {

        uint value;
        uint volume;
        int udlPrice;
        uint iv;
        uint len = tokenIds[symbol].length;
        OptionData memory opt;

        if (len > 0) {

            for (uint i = 0; i < len && i < limit; i++) {
                
                uint48 id = tokenIds[symbol][0];
                OrderData memory ord = orders[id];
                if (opt.udlFeed == address(0)) {
                    opt = options[ord.optId];
                }

                if (i == 0) {
                    udlPrice = getUdlPrice(opt);
                    uint _now = getUdlNow(opt);
                    iv = uint(calcIntrinsicValue(opt));
                    require(opt.maturity <= _now, "maturity not reached");
                }

                require(ord.id == id, "invalid order id");
                
                volume = volume.add(ord.written).add(ord.holding);

                if (ord.written > 0) {
                    value.add(
                        liquidateAfterMaturity(ord, symbol, msg.sender, iv.mul(ord.written))
                    );
                } else {
                    removeOrder(symbol, ord);
                }
            }
        }

        if (volume > 0) {
            emit LiquidateExpired(tokenAddress[symbol], msg.sender, volume);
        }

        if (len <= limit) {
            delete tokenIds[symbol];
            delete tokenAddress[symbol];
        }
    }

    function liquidateOptions(uint id) external returns (uint value) {
        
        OrderData memory ord = orders[id];
        require(ord.id == id && ord.written > 0, "invalid order id");
        OptionData memory opt = options[ord.optId];

        address token = resolveToken(id);
        string memory symbol = OptionToken(token).symbol();
        uint iv = uint(calcIntrinsicValue(opt)).mul(ord.written);
        
        if (getUdlNow(opt) >= opt.maturity) {
            value = liquidateAfterMaturity(ord, symbol, token, iv);
            emit LiquidateExpired(token, msg.sender, ord.written);
        } else {
            FeedData memory fd = feeds[opt.udlFeed];
            value = liquidateBeforeMaturity(ord, opt, fd, symbol, token, iv);
        }
    }

    function calcDebt(address owner) external view returns (uint debt) {

        debt = creditProvider.calcDebt(owner);
    }
    
    function calcSurplus(address owner) public view returns (uint) {
        
        uint coll = calcCollateral(owner);
        uint bal = creditProvider.balanceOf(owner);
        if (bal >= coll) {
            return bal.sub(coll);
        }
        return 0;
    }

    function setCollateral(address owner) external {

        collateral[owner] = calcCollateral(owner);
    }
    
    function calcCollateral(address owner) public view returns (uint) {
        
        int coll;
        uint48[] memory ids = book[owner];

        for (uint i = 0; i < ids.length; i++) {

            OrderData memory ord = orders[ids[i]];
            OptionData memory opt = options[ord.optId];

            if (isValid(ord)) {
                coll = coll.add(
                    calcIntrinsicValue(opt).mul(
                        int(ord.written).sub(int(ord.holding))
                    )
                ).add(int(calcCollateral(feeds[opt.udlFeed].upperVol, ord.written, opt)));
            }
        }

        coll = coll.div(int(volumeBase));

        if (coll < 0)
            return 0;
        return uint(coll);
    }

    function calcCollateral(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        public
        view
        returns (uint)
    {
        (OptionData memory opt,,) = createOptionInMemory(udlFeed, optType, strike, maturity);
        return calcCollateral(opt, volume);
    }

    function calcExpectedPayout(address owner) external view returns (int payout) {

        uint48[] memory ids = book[owner];

        for (uint i = 0; i < ids.length; i++) {

            OrderData memory ord = orders[ids[i]];
            OptionData memory opt = options[ord.optId];

            if (isValid(ord)) {
                payout = payout.add(
                    calcIntrinsicValue(opt).mul(
                        int(ord.holding).sub(int(ord.written))
                    )
                );
            }
        }

        payout = payout.div(int(volumeBase));
    }

    function createSymbol(string memory symbol, address udlFeed) public returns (address tk) {

        tk = factory.create(symbol, udlFeed);
        tokenAddress[symbol] = tk;
        prefetchFeedData(udlFeed);
        emit CreateSymbol(tk, msg.sender);
    }

    function prefetchFeedData(address udlFeed) public {
        
        feeds[udlFeed] = getFeedData(udlFeed);
    }

    function resolveSymbol(uint id) external view returns (string memory) {
        
        OptionData memory opt = options[orders[id].optId];
        return getOptionSymbol(opt);
    }

    function resolveToken(uint id) public view returns (address) {
        
        OptionData memory opt = options[orders[id].optId];
        address addr = tokenAddress[getOptionSymbol(opt)];
        require(addr != address(0), "token not found");
        return addr;
    }

    function resolveToken(string memory symbol) public view returns (address) {
        
        address addr = tokenAddress[symbol];
        require(addr != address(0), "token not found");
        return addr;
    }

    function getBook(address owner)
        external view
        returns (
            string memory symbols,
            uint[] memory holding,
            uint[] memory written,
            int[] memory iv
        )
    {
        uint48[] memory ids = book[owner];
        holding = new uint[](ids.length);
        written = new uint[](ids.length);
        iv = new int[](ids.length);

        for (uint i = 0; i < ids.length; i++) {
            OrderData memory ord = orders[ids[i]];
            OptionData memory opt = options[ord.optId];
            if (i == 0) {
                symbols = getOptionSymbol(opt);
            } else {
                symbols = string(abi.encodePacked(symbols, "\n", getOptionSymbol(opt)));
            }
            holding[i] = ord.holding;
            written[i] = ord.written;
            iv[i] = calcIntrinsicValue(opt);
        }
    }

    function getBookLength() external view returns (uint len) {
        
        for (uint i = 0; i < serial; i++) {
            if (isValid(orders[i])) {
                len++;
            }
        }
    }

    function getVolumeBase() external view returns (uint) {
        
        return volumeBase;
    }
    
    function calcIntrinsicValue(uint id) external view returns (int) {
        
        return calcIntrinsicValue(options[orders[id].optId]);
    }

    function calcIntrinsicValue(
        address udlFeed,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        external
        view
        returns (int)
    {
        (OptionData memory opt,,) = createOptionInMemory(udlFeed, optType, strike, maturity);
        return calcIntrinsicValue(opt);
    }

    function permit(
        address from,
        address to,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        private
    {
        require(deadline >= block.timestamp, "permit expired");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(PERMIT_TYPEHASH, from, to, value, nonces[from]++, deadline)
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == from, "invalid signature");
    }

    function createOrder(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity,
        address to
    )
        private 
        returns (uint id, address tk)
    {
        require(settings.getUdlFeed(udlFeed) > 0, "feed not allowed");
        require(volume > 0, "invalid volume");
        require(maturity > time.getNow(), "invalid maturity");

        uint48 _serial = serial;
        bool _updateSerial = false;

        (OptionData memory opt, string memory symbol, bool cached) =
            createOptionInMemory(udlFeed, optType, strike, maturity);
        if (!cached) {
            opt.id = _serial++;
            _updateSerial = true;
            options[opt.id] = opt;
            optIndex[symbol] = opt.id;
        }

        OrderData memory result = findOrder(msg.sender, symbol);

        if (isValid(result)) {
            id = result.id;
            orders[id].written = uint(result.written).add(volume).toUint120();
            orders[id].holding = uint(result.holding).add(volume).toUint120();
        } else {
            id = _serial++;
            _updateSerial = true;
            orders[id] = OrderData(
                uint48(id),
                opt.id,
                msg.sender,
                volume.toUint120(),
                volume.toUint120()
            );
            book[msg.sender].push(uint48(id));
            ordIndex[msg.sender][symbol] = uint48(id);
            tokenIds[symbol].push(uint48(id));
        }

        tk = tokenAddress[symbol];
        if (tk == address(0)) {
            tk = createSymbol(symbol, udlFeed);
        }
        OptionToken(tk).issue(to, volume);

        if (_updateSerial) {
            serial = _serial;
        }
        
        collateral[msg.sender] = collateral[msg.sender].add(
            calcCollateral(opt, volume)
        );

        emit WriteOptions(tk, msg.sender, volume, id);
    }

    function transferOwnershipInternal(
        string memory symbol,
        address from,
        address to,
        uint volume
    )
        private
    {
        OrderData memory ord = findOrder(from, symbol);

        require(isValid(ord), "order not found");
        require(volume <= ord.holding, "invalid volume");
                
        OrderData memory toOrd = findOrder(to, symbol);

        if (!isValid(toOrd)) {
            toOrd.id = serial++;
            toOrd.optId = ord.optId;
            toOrd.owner = address(to);
            toOrd.written = 0;
            toOrd.holding = volume.toUint120();
            orders[toOrd.id] = toOrd;
            book[to].push(toOrd.id);
            ordIndex[to][symbol] = toOrd.id;
            tokenIds[symbol].push(toOrd.id);
        } else {
            orders[toOrd.id].holding = uint(toOrd.holding).add(volume).toUint120();
        }
        
        uint120 _holding = uint(ord.holding).sub(volume).toUint120();
        orders[ord.id].holding = _holding;

        ensureFunds(ord.owner);

        if (shouldRemove(ord.written, _holding)) {
            removeOrder(symbol, ord);
        }
    }

    function createOptionInMemory(
        address udlFeed,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        private
        view
        returns (OptionData memory opt, string memory symbol, bool cached)
    {
        OptionData memory aux =
            OptionData(0, udlFeed, optType, strike.toUint120(), maturity.toUint32());

        symbol = getOptionSymbol(aux);

        opt = options[optIndex[symbol]];
        if (opt.id == 0) {
            opt = aux;
        } else {
            cached = true;
        }
    }

    function getFeedData(address udlFeed) private view returns (FeedData memory fd) {
        
        UnderlyingFeed feed = UnderlyingFeed(udlFeed);

        uint vol = feed.getDailyVolatility(settings.getVolatilityPeriod());

        fd = FeedData(
            feed.calcLowerVolatility(uint(vol)).toUint120(),
            feed.calcUpperVolatility(uint(vol)).toUint120()
        );
    }

    function findOrder(
        address owner,
        string memory symbol
    )
        private
        view
        returns (OrderData memory)
    {
        uint48 id = ordIndex[owner][symbol];
        if (id > 0) {
            return orders[id];
        }
    }

    function liquidateAfterMaturity(
        OrderData memory ord,
        string memory symbol,
        address token,
        uint iv
    )
        private
        returns (uint value)
    {
        if (iv > 0) {
            value = iv.div(volumeBase);
            creditProvider.processPayment(ord.owner, token, value);
        }
    
        removeOrder(symbol, ord);
    }

    function liquidateBeforeMaturity(
        OrderData memory ord,
        OptionData memory opt,
        FeedData memory fd,
        string memory symbol,
        address token,
        uint iv
    )
        private
        returns (uint value)
    {
        uint volume = calcLiquidationVolume(ord, opt, fd);
        value = calcLiquidationValue(ord, opt, fd, iv, volume);
        
        uint120 _written = uint(ord.written).sub(volume).toUint120();
        orders[ord.id].written = _written;
        
        if (shouldRemove(_written, ord.holding)) {
            removeOrder(symbol, ord);
        }

        creditProvider.processPayment(ord.owner, token, value);
        emit LiquidateEarly(token, msg.sender, volume);
    }

    function calcLiquidationVolume(
        OrderData memory ord,
        OptionData memory opt,
        FeedData memory fd
    )
        private
        view
        returns (uint volume)
    {    
        uint bal = creditProvider.balanceOf(ord.owner);
        uint coll = calcCollateral(ord.owner);
        require(coll > bal, "unfit for liquidation");

        volume = coll.sub(bal).mul(volumeBase).mul(ord.written).div(
            calcCollateral(
                uint(fd.upperVol).sub(uint(fd.lowerVol)),
                ord.written,
                opt
            )
        );

        volume = MoreMath.min(volume, ord.written);
    }

    function calcLiquidationValue(
        OrderData memory ord,
        OptionData memory opt,
        FeedData memory fd,
        uint iv,
        uint volume
    )
        private
        view
        returns (uint value)
    {    
        value = calcCollateral(fd.lowerVol, ord.written, opt).add(iv)
            .mul(volume.toUint120()).div(ord.written).div(volumeBase);
    }

    function shouldRemove(uint120 w, uint120 h) private pure returns (bool) {

        return w == 0 && h == 0;
    }
    
    function removeOrder(string memory symbol, OrderData memory ord) private {
        
        Arrays.removeItem(tokenIds[symbol], ord.id);
        Arrays.removeItem(book[ord.owner], ord.id);
        delete ordIndex[ord.owner][symbol];
        delete orders[ord.id];
    }

    function getOptionSymbol(OptionData memory opt) private view returns (string memory symbol) {    

        symbol = string(abi.encodePacked(
            UnderlyingFeed(opt.udlFeed).symbol(),
            "-",
            "E",
            opt._type == OptionType.CALL ? "C" : "P",
            "-",
            MoreMath.toString(opt.strike),
            "-",
            MoreMath.toString(opt.maturity)
        ));
    }
    
    function ensureFunds(address owner) private view {
        
        require(
            creditProvider.balanceOf(owner) >= collateral[owner],
            "insufficient collateral"
        );
    }
    
    function isValid(OrderData memory ord) private pure returns (bool) {
        
        return ord.id > 0;
    }

    function calcCollateral(
        OptionData memory opt,
        uint volume
    )
        private
        view
        returns (uint)
    {
        FeedData memory fd = feeds[opt.udlFeed];
        if (fd.lowerVol == 0 || fd.upperVol == 0) {
            fd = getFeedData(opt.udlFeed);
        }

        int coll = calcIntrinsicValue(opt).mul(int(volume)).add(
            int(calcCollateral(fd.upperVol, volume, opt))
        ).div(int(volumeBase));

        return coll > 0 ? uint(coll) : 0;
    }
    
    function calcCollateral(uint vol, uint volume, OptionData memory opt) private view returns (uint) {
        
        return (vol.mul(volume).mul(
            MoreMath.sqrt(daysToMaturity(opt)))
        ).div(sqrtTimeBase);
    }
    
    function calcIntrinsicValue(OptionData memory opt) private view returns (int value) {
        
        int udlPrice = getUdlPrice(opt);
        int strike = int(opt.strike);

        if (opt._type == OptionType.CALL) {
            value = MoreMath.max(0, udlPrice.sub(strike));
        } else if (opt._type == OptionType.PUT) {
            value = MoreMath.max(0, strike.sub(udlPrice));
        }
    }
    
    function daysToMaturity(OptionData memory opt) private view returns (uint d) {
        
        uint _now = getUdlNow(opt);
        if (opt.maturity > _now) {
            d = (timeBase.mul(uint(opt.maturity).sub(uint(_now)))).div(1 days);
        } else {
            d = 0;
        }
    }

    function getUdlPrice(OptionData memory opt) private view returns (int answer) {

        if (opt.maturity > time.getNow()) {
            (,answer) = UnderlyingFeed(opt.udlFeed).getLatestPrice();
        } else {
            (,answer) = UnderlyingFeed(opt.udlFeed).getPrice(opt.maturity);
        }
    }

    function getUdlNow(OptionData memory opt) private view returns (uint timestamp) {

        (timestamp,) = UnderlyingFeed(opt.udlFeed).getLatestPrice();
    }
}