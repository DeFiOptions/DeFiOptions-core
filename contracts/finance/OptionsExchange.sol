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
import "../utils/SafeERC20.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./CreditProvider.sol";
import "./OptionToken.sol";
import "./OptionTokenFactory.sol";
import "./UnderlyingVault.sol";

contract OptionsExchange is ManagedContract {

    using SafeCast for uint;
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using SignedSafeMath for int;
    
    enum OptionType { CALL, PUT }
    
    struct OptionData {
        address udlFeed;
        OptionType _type;
        uint120 strike;
        uint32 maturity;
    }

    struct FeedData {
        uint120 lowerVol;
        uint120 upperVol;
    }
    
    TimeProvider private time;
    ProtocolSettings private settings;
    CreditProvider private creditProvider;
    OptionTokenFactory private factory;
    UnderlyingVault private vault;

    mapping(address => uint) public collateral;
    mapping(address => OptionData) private options;
    mapping(address => FeedData) private feeds;
    mapping(address => address[]) private book;
    mapping(string => address) private tokenAddress;
    mapping(address => mapping(address => uint)) private allowed;
    
    uint public volumeBase;
    uint private timeBase;
    uint private sqrtTimeBase;

    event WithdrawTokens(address indexed from, uint value);

    event CreateSymbol(address indexed token, address indexed sender);

    event Approval(address indexed owner, address indexed spender, uint value);

    event WriteOptions(
        address indexed token,
        address indexed issuer,
        address indexed onwer,
        uint volume
    );

    event LiquidateEarly(
        address indexed token,
        address indexed sender,
        address indexed onwer,
        uint volume
    );

    event LiquidateExpired(
        address indexed token,
        address indexed sender,
        address indexed onwer,
        uint volume
    );

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        factory = OptionTokenFactory(deployer.getContractAddress("OptionTokenFactory"));
        vault = UnderlyingVault(deployer.getContractAddress("UnderlyingVault"));

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
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
        depositTokens(to, token, value);
    }

    function depositTokens(address to, address token, uint value) public {

        IERC20 t = IERC20(token);
        t.safeTransferFrom(msg.sender, address(creditProvider), value);
        creditProvider.addBalance(to, token, value);
    }

    function balanceOf(address owner) external view returns (uint) {

        return creditProvider.balanceOf(owner);
    }

    function allowance(address owner, address spender) external view returns (uint) {

        return allowed[owner][spender];
    }

    function approve(address spender, uint value) external returns (bool) {

        require(spender != address(0));
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferBalance(
        address from, 
        address to, 
        uint value
    )
        external
    {
        uint allw = allowed[from][msg.sender];
        if (allw >= value) {
            allowed[from][msg.sender] = allw.sub(value);
        } else {
            creditProvider.ensureCaller(msg.sender);
        }
        creditProvider.transferBalance(from, to, value);
        ensureFunds(from);
    }

    function transferBalance(address to, uint value) public {

        creditProvider.transferBalance(msg.sender, to, value);
        ensureFunds(msg.sender);
    }

    function underlyingBalance(address owner, address _tk) external view returns (uint) {

        return vault.balanceOf(owner, _tk);
    }
    
    function withdrawTokens(uint value) external {
        
        require(value <= calcSurplus(msg.sender), "insufficient surplus");
        creditProvider.withdrawTokens(msg.sender, value);
        emit WithdrawTokens(msg.sender, value);
    }

    function createSymbol(
        address udlFeed,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        public
        returns (address tk)
    {
        ensureFeedIsAlowed(udlFeed);

        (OptionData memory opt, string memory symbol) =
            createOptionInMemory(udlFeed, optType, strike, maturity);

        require(tokenAddress[symbol] == address(0), "already created");

        tk = factory.create(symbol, udlFeed);
        tokenAddress[symbol] = tk;
        options[tk] = opt;
        prefetchFeedData(udlFeed);

        emit CreateSymbol(tk, msg.sender);
    }

    function getOptionSymbol(
        address udlFeed,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        public
        view
        returns (string memory symbol)
    {    
        symbol = string(abi.encodePacked(
            UnderlyingFeed(udlFeed).symbol(),
            "-",
            "E",
            optType == OptionType.CALL ? "C" : "P",
            "-",
            MoreMath.toString(strike),
            "-",
            MoreMath.toString(maturity)
        ));
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
        returns (address _tk)
    {
        (OptionData memory opt, string memory symbol) =
            createOptionInMemory(udlFeed, optType, strike, maturity);
        (_tk) = writeOptionsInternal(opt, symbol, volume, to);
        ensureFunds(msg.sender);
    }

    function writeCovered(
        address udlFeed,
        uint volume,
        uint strike, 
        uint maturity,
        address to
    )
        external 
        returns (address _tk)
    {
        (OptionData memory opt, string memory symbol) =
            createOptionInMemory(udlFeed, OptionType.CALL, strike, maturity);
        _tk = tokenAddress[symbol];

        if (_tk == address(0)) {
            _tk = createSymbol(opt.udlFeed, OptionType.CALL, strike, maturity);
        }
        
        address underlying = getUnderlyingAddr(opt);
        require(underlying != address(0), "underlying token not set");
        IERC20(underlying).safeTransferFrom(msg.sender, address(vault), volume);
        vault.lock(msg.sender, _tk, volume);

        writeOptionsInternal(opt, symbol, volume, to);
        ensureFunds(msg.sender);
    }
    
    function transferOwnership(
        string calldata symbol,
        address from,
        address to,
        uint value
    )
        external
    {
        require(tokenAddress[symbol] == msg.sender, "unauthorized ownership transfer");
        
        OptionToken tk = OptionToken(msg.sender);
        
        if (tk.writtenVolume(from) == 0 && tk.balanceOf(from) == 0) {
            Arrays.removeItem(book[from], msg.sender);
        }

        if (tk.writtenVolume(to) == 0 && tk.balanceOf(to) == value) {
            book[to].push(msg.sender);
        }

        ensureFunds(from);
    }

    function release(address owner, uint udl, uint coll) public {

        OptionToken tk = OptionToken(msg.sender);
        require(tokenAddress[tk.symbol()] == msg.sender, "unauthorized release");

        OptionData memory opt = options[msg.sender];

        if (udl > 0) {
            vault.release(owner,  msg.sender, opt.udlFeed, udl);
        }
        
        if (coll > 0) {
            uint c = collateral[owner];
            collateral[owner] = c.sub(
                MoreMath.min(c, calcCollateral(opt, coll))
            );
        }
    }

    function cleanUp(address owner, address _tk) public {

        OptionToken tk = OptionToken(_tk);

        if (tk.balanceOf(owner) == 0 && tk.writtenVolume(owner) == 0) {
            Arrays.removeItem(book[owner], _tk);
        }
    }

    function liquidateExpired(address _tk, address[] calldata owners) external {

        OptionData memory opt = options[_tk];
        OptionToken tk = OptionToken(_tk);
        require(getUdlNow(opt) >= opt.maturity, "option not expired");
        uint iv = uint(calcIntrinsicValue(opt));

        for (uint i = 0; i < owners.length; i++) {
            liquidateOptions(owners[i], opt, tk, true, iv);
        }
    }

    function liquidateOptions(address _tk, address owner) public returns (uint value) {
        
        OptionData memory opt = options[_tk];
        require(opt.udlFeed != address(0), "token not found");

        OptionToken tk = OptionToken(_tk);
        require(tk.writtenVolume(owner) > 0, "invalid token");

        bool isExpired = getUdlNow(opt) >= opt.maturity;
        uint iv = uint(calcIntrinsicValue(opt));
        
        value = liquidateOptions(owner, opt, tk, isExpired, iv);
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
        address[] memory _book = book[owner];

        for (uint i = 0; i < _book.length; i++) {

            address _tk = _book[i];
            OptionToken tk = OptionToken(_tk);
            OptionData memory opt = options[_tk];

            uint written = tk.uncoveredVolume(owner);
            uint holding = tk.balanceOf(owner);

            coll = coll.add(
                calcIntrinsicValue(opt).mul(
                    int(written).sub(int(holding))
                )
            ).add(int(calcCollateral(feeds[opt.udlFeed].upperVol, written, opt)));
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
        (OptionData memory opt,) = createOptionInMemory(udlFeed, optType, strike, maturity);
        return calcCollateral(opt, volume);
    }

    function calcExpectedPayout(address owner) external view returns (int payout) {

        address[] memory _book = book[owner];

        for (uint i = 0; i < _book.length; i++) {

            OptionToken tk = OptionToken(_book[i]);
            OptionData memory opt = options[_book[i]];

            uint written = tk.writtenVolume(owner);
            uint holding = tk.balanceOf(owner);

            payout = payout.add(
                calcIntrinsicValue(opt).mul(
                    int(holding).sub(int(written))
                )
            );
        }

        payout = payout.div(int(volumeBase));
    }
    
    function calcIntrinsicValue(address _tk) external view returns (int) {
        
        return calcIntrinsicValue(options[_tk]);
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
        (OptionData memory opt,) = createOptionInMemory(udlFeed, optType, strike, maturity);
        return calcIntrinsicValue(opt);
    }

    function getUnderlyingPrice(string calldata symbol) external view returns (int) {
        
        address _ts = tokenAddress[symbol];
        require(_ts != address(0), "token not found");
        return getUdlPrice(options[_ts]);
    }

    function resolveToken(string memory symbol) public view returns (address) {
        
        address addr = tokenAddress[symbol];
        require(addr != address(0), "token not found");
        return addr;
    }

    function prefetchFeedData(address udlFeed) public {
        
        feeds[udlFeed] = getFeedData(udlFeed);
    }

    function getBook(address owner)
        external view
        returns (
            string memory symbols,
            address[] memory tokens,
            uint[] memory holding,
            uint[] memory written,
            int[] memory iv
        )
    {
        tokens = book[owner];
        holding = new uint[](tokens.length);
        written = new uint[](tokens.length);
        iv = new int[](tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            OptionToken tk = OptionToken(tokens[i]);
            OptionData memory opt = options[tokens[i]];
            if (i == 0) {
                symbols = getOptionSymbol(opt);
            } else {
                symbols = string(abi.encodePacked(symbols, "\n", getOptionSymbol(opt)));
            }
            holding[i] = tk.balanceOf(owner);
            written[i] = tk.writtenVolume(owner);
            iv[i] = calcIntrinsicValue(opt);
        }
    }

    function ensureFunds(address owner) private view {
        
        require(
            creditProvider.balanceOf(owner) >= collateral[owner],
            "insufficient collateral"
        );
    }

    function createOptionInMemory(
        address udlFeed,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        private
        view
        returns (OptionData memory opt, string memory symbol)
    {
        opt = OptionData(udlFeed, optType, strike.toUint120(), maturity.toUint32());
        symbol = getOptionSymbol(opt);
    }

    function writeOptionsInternal(
        OptionData memory opt,
        string memory symbol,
        uint volume,
        address to
    )
        private 
        returns (address _tk)
    {
        ensureFeedIsAlowed(opt.udlFeed);
        require(volume > 0, "invalid volume");
        require(opt.maturity > time.getNow(), "invalid maturity");

        _tk = tokenAddress[symbol];
        if (_tk == address(0)) {
            _tk = createSymbol(opt.udlFeed, opt._type, opt.strike, opt.maturity);
        }

        OptionToken tk = OptionToken(_tk);
        if (tk.writtenVolume(msg.sender) == 0 && tk.balanceOf(msg.sender) == 0) {
            book[msg.sender].push(_tk);
        }
        if (msg.sender != to && tk.writtenVolume(to) == 0 && tk.balanceOf(to) == 0) {
            book[to].push(_tk);
        }
        tk.issue(msg.sender, to, volume);

        if (options[_tk].udlFeed == address(0)) {
            options[_tk] = opt;
        }
        
        uint v = MoreMath.min(volume, tk.uncoveredVolume(msg.sender));
        if (v > 0) {
            collateral[msg.sender] = collateral[msg.sender].add(
                calcCollateral(opt, v)
            );
        }

        emit WriteOptions(_tk, msg.sender, to, volume);
    }

    function liquidateOptions(
        address owner,
        OptionData memory opt,
        OptionToken tk,
        bool isExpired,
        uint iv
    )
        private
        returns (uint value)
    {
        uint written = isExpired ?
            tk.writtenVolume(owner) :
            tk.uncoveredVolume(owner);
        iv = iv.mul(written);

        if (isExpired) {
            value = liquidateAfterMaturity(owner, tk, opt.udlFeed, written, iv);
            emit LiquidateExpired(address(tk), msg.sender, owner, written);
        } else {
            require(written > 0, "invalid volume");
            value = liquidateBeforeMaturity(owner, opt, tk, written, iv);
        }
    }

    function liquidateAfterMaturity(
        address owner,
        OptionToken tk,
        address feed,
        uint written,
        uint iv
    )
        private
        returns (uint value)
    {
        if (iv > 0) {
            value = iv.div(volumeBase);
            vault.liquidate(owner, address(tk), feed, value);
            creditProvider.processPayment(owner, address(tk), value);
        }

        vault.release(owner, address(tk), feed, uint(-1));

        if (written > 0) {
            tk.burn(owner, written);
        }
    }

    function liquidateBeforeMaturity(
        address owner,
        OptionData memory opt,
        OptionToken tk,
        uint written,
        uint iv
    )
        private
        returns (uint value)
    {
        FeedData memory fd = feeds[opt.udlFeed];

        uint volume = calcLiquidationVolume(owner, opt, fd, written);
        value = calcLiquidationValue(opt, fd.lowerVol, written, volume, iv)
            .div(volumeBase);
        creditProvider.processPayment(owner, address(tk), value);

        if (volume > 0) {
            tk.burn(owner, volume);
        }

        emit LiquidateEarly(address(tk), msg.sender, owner, volume);
    }

    function calcLiquidationVolume(
        address owner,
        OptionData memory opt,
        FeedData memory fd,
        uint written
    )
        private
        view
        returns (uint volume)
    {    
        uint bal = creditProvider.balanceOf(owner);
        uint coll = calcCollateral(owner);
        require(coll > bal, "unfit for liquidation");

        volume = coll.sub(bal).mul(volumeBase).mul(written).div(
            calcCollateral(
                uint(fd.upperVol).sub(uint(fd.lowerVol)),
                written,
                opt
            )
        );

        volume = MoreMath.min(volume, written);
    }

    function calcLiquidationValue(
        OptionData memory opt,
        uint vol,
        uint written,
        uint volume,
        uint iv
    )
        private
        view
        returns (uint value)
    {    
        value = calcCollateral(vol, written, opt).add(iv).mul(volume).div(written);
    }

    function getFeedData(address udlFeed) private view returns (FeedData memory fd) {
        
        UnderlyingFeed feed = UnderlyingFeed(udlFeed);

        uint vol = feed.getDailyVolatility(settings.getVolatilityPeriod());

        fd = FeedData(
            feed.calcLowerVolatility(uint(vol)).toUint120(),
            feed.calcUpperVolatility(uint(vol)).toUint120()
        );
    }

    function getOptionSymbol(OptionData memory opt) private view returns (string memory symbol) {    

        symbol = getOptionSymbol(
            opt.udlFeed,
            opt._type,
            opt.strike,
            opt.maturity
        );
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

        if (opt._type == OptionType.PUT) {
            int max = int(uint(opt.strike).mul(volume).div(volumeBase));
            coll = MoreMath.min(coll, max);
        }

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

    function getUnderlyingAddr(OptionData memory opt) private view returns (address) {
        
        return UnderlyingFeed(opt.udlFeed).getUnderlyingAddr();
    }

    function getUdlNow(OptionData memory opt) private view returns (uint timestamp) {

        (timestamp,) = UnderlyingFeed(opt.udlFeed).getLatestPrice();
    }

    function ensureFeedIsAlowed(address udlFeed) private view {
        
        require(settings.getUdlFeed(udlFeed) > 0, "feed not allowed");
    }
}
