pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../governance/ProtocolSettings.sol";
import "../utils/ERC20.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/Arrays.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";
import "./CreditProvider.sol";
import "./OptionToken.sol";

contract OptionsExchange is ManagedContract {

    using SafeMath for uint;
    using SignedSafeMath for int;
    
    enum OptionType { CALL, PUT }
    
    struct OrderData {
        uint id;
        address owner;
        address udlFeed;
        uint lowerVol;
        uint upperVol;
        uint written;
        uint holding;
        OptionData option;
    }
    
    struct OptionData {
        OptionType _type;
        uint strike;
        uint maturity;
    }
    
    TimeProvider private time;
    ProtocolSettings private settings;
    CreditProvider private creditProvider;

    mapping(uint => OrderData) private orders;
    mapping(address => uint[]) private book;
    mapping(string => address) private optionTokens;
    mapping(string => uint[]) private tokensIds;
    
    uint private serial;
    uint private bookLength;
    uint private volumeBase;
    uint private timeBase;
    uint private sqrtTimeBase;
    address private creditToken;

    event WriteOptions(string indexed code, address indexed issuer, uint volume, uint id);

    event LiquidateCode(string indexed code, int udlPrice, uint value);

    constructor(address deployer) public {

        Deployer(deployer).setContractAddress("OptionsExchange");
    }

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        creditProvider = CreditProvider(deployer.getContractAddress("CreditProvider"));
        creditToken = deployer.getContractAddress("CreditToken");
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));

        serial = 1;
        volumeBase = 1e9;
        timeBase = 1e18;
        sqrtTimeBase = 1e9;
    }

    function depositTokens(address to, address token, uint value) external {

        ERC20 t = ERC20(token);
        t.transferFrom(msg.sender, address(this), value);
        t.approve(address(creditProvider), value);
        creditProvider.depositTokens(to, token, value);
    }

    function balanceOf(address owner) external view returns (uint) {

        return creditProvider.balanceOf(owner);
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
        returns (uint id)
    {
        id = createOrder(udlFeed, volume, optType, strike, maturity);
        ensureFunds(msg.sender);
    }

    function writtenVolume(string calldata code, address owner) external view returns (uint) {

        return findOrder(book[owner], code).written;
    }

    function transferOwnership(
        string calldata code,
        address from,
        address to,
        uint volume
    )
        external
    {
        require(optionTokens[code] == msg.sender, "unauthorized ownership transfer");

        OrderData memory ord = findOrder(book[from], code);

        require(isValid(ord), "order not found");
        require(volume <= ord.holding, "invalid volume");
                
        OrderData memory toOrd = findOrder(book[to], code);

        if (!isValid(toOrd)) {
            toOrd = orders[ord.id];
            toOrd.id = serial++;
            toOrd.owner = address(to);
            toOrd.written = 0;
            toOrd.holding = 0;
            orders[toOrd.id] = toOrd;
            book[to].push(toOrd.id);
            bookLength++;
            tokensIds[code].push(toOrd.id);
        }
        
        orders[ord.id].holding = orders[ord.id].holding.sub(volume);
        orders[toOrd.id].holding = orders[toOrd.id].holding.add(volume);
        ensureFunds(ord.owner);

        if (shouldRemove(ord.id)) {
            removeOrder(code, ord.id);
        }
    }

    function burnOptions(
        string calldata code,
        address owner,
        uint volume
    )
        external
    {
        require(optionTokens[code] == msg.sender, "unauthorized burn");
        
        OrderData memory ord = findOrder(book[owner], code);
        
        require(isValid(ord), "order not found");
        require(ord.written >= volume && ord.holding >= volume, "invalid volume");
        
        orders[ord.id].written = orders[ord.id].written.sub(volume);
        orders[ord.id].holding = orders[ord.id].holding.sub(volume);

        if (shouldRemove(ord.id)) {
            removeOrder(code, ord.id);
        }
    }

    function liquidateCode(string calldata code) external {

        require(optionTokens[code] == msg.sender, "unauthorized liquidate");

        int udlPrice;
        uint value;
        uint _now;

        uint[] memory ids = tokensIds[code];
        for (uint i = 0; i < ids.length; i++) {

            uint id = ids[i];

            if (_now == 0) {
                _now = getUdlNow(orders[id]);
                udlPrice = getUdlPrice(orders[id]);
            }

            require(orders[id].id == id, "invalid order id");
            require(orders[id].option.maturity <= _now, "maturity not reached");

            if (orders[id].written > 0) {
                value.add(liquidateOptions(id));
            } else {
                removeOrder(code, id);
            }
        }

        delete tokensIds[code];
        delete optionTokens[code];

        emit LiquidateCode(code, udlPrice, value);
    }

    function liquidateOptions(uint id) public returns (uint value) {
        
        OrderData memory ord = orders[id];
        require(ord.id == id && ord.written > 0, "invalid order id");

        address token = resolveToken(id);
        string memory code = OptionToken(token).getCode();
        uint iv = uint(calcIntrinsicValue(ord)).mul(ord.written);
        
        if (getUdlNow(ord) >= ord.option.maturity) {
            
            if (iv > 0) {
                value = iv.div(volumeBase);
                creditProvider.processPayment(ord.owner, token, value);
            }
        
            removeOrder(code, id);
            
        } else {
            value = liquidateBeforeMaturity(ord, code, token, iv);
        }
    }

    function calcDebt(address owner) external view returns (uint debt) {

        debt = creditProvider.calcDebt(owner);
    }
    
    function calcSurplus(address owner) public view returns (uint) {
        
        uint collateral = calcCollateral(owner);
        uint bal = creditProvider.balanceOf(owner);
        if (bal >= collateral) {
            return bal.sub(collateral);
        }
        return 0;
    }

    function calcCollateral(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        external
        view
        returns (uint)
    {
        OrderData memory ord = createOrderInMemory(udlFeed, volume, optType, strike, maturity);

        int collateral = calcIntrinsicValue(ord).mul(int(volume)).add(
            int(calcCollateral(ord.upperVol, ord))
        ).div(int(volumeBase));

        return collateral > 0 ? uint(collateral) : 0;
    }
    
    function calcCollateral(address owner) public view returns (uint) {
        
        int collateral;

        for (uint i = 0; i < book[owner].length; i++) {

            OrderData memory ord = orders[book[owner][i]];

            if (isValid(ord)) {
                collateral = collateral.add(
                    calcIntrinsicValue(ord).mul(
                        int(ord.written).sub(int(ord.holding))
                    )
                ).add(int(calcCollateral(ord.upperVol, ord)));
            }
        }

        collateral = collateral.div(int(volumeBase));

        if (collateral < 0)
            return 0;
        return uint(collateral);
    }

    function resolveCode(uint id) external view returns (string memory) {
        
        return getOptionCode(orders[id]);
    }

    function resolveToken(uint id) public view returns (address) {
        
        address addr = optionTokens[getOptionCode(orders[id])];
        require(addr != address(0), "token not found");
        return addr;
    }

    function getBookLength() external view returns (uint) {
        
        return bookLength;
    }
    
    function calcLowerCollateral(uint id) external view returns (uint) {
        
        return calcCollateral(orders[id].lowerVol, orders[id]).div(volumeBase);
    }
    
    function calcUpperCollateral(uint id) external view returns (uint) {
        
        return calcCollateral(orders[id].upperVol, orders[id]).div(volumeBase);
    }
    
    function calcIntrinsicValue(uint id) external view returns (int) {
        
        return calcIntrinsicValue(orders[id]);
    }

    function createOrder(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        private 
        returns (uint id)
    {
        require(udlFeed == address(0) || settings.getUdlFeed(udlFeed) > 0, "feed not allowed");
        require(volume > 0, "invalid volume");
        require(maturity > time.getNow(), "invalid maturity");

        OrderData memory ord = createOrderInMemory(udlFeed, volume, optType, strike, maturity);
        id = serial++;
        ord.id = id;

        string memory code = getOptionCode(ord);

        OrderData memory result = findOrder(book[msg.sender], code);
        if (isValid(result)) {
            orders[result.id].written = orders[result.id].written.add(volume);
            orders[result.id].holding = orders[result.id].holding.add(volume);
            id = result.id;
        } else {
            orders[id] = ord;
            book[msg.sender].push(ord.id);
            bookLength++;
            tokensIds[code].push(ord.id);
        }

        if (optionTokens[code] == address(0)) {
            optionTokens[code] = address(
                new OptionToken(
                    code,
                    address(this),
                    address(creditProvider)
                )
            );
        }
        
        OptionToken(optionTokens[code]).issue(msg.sender, volume);
        emit WriteOptions(code, msg.sender, volume, id);
    }

    function createOrderInMemory(
        address udlFeed,
        uint volume,
        OptionType optType,
        uint strike, 
        uint maturity
    )
        private
        view
        returns (OrderData memory ord)
    {
        OptionData memory opt = OptionData(optType, strike, maturity);

        UnderlyingFeed feed = udlFeed != address(0) ?
            UnderlyingFeed(udlFeed) :
            UnderlyingFeed(settings.getDefaultUdlFeed());

        uint vol = feed.getDailyVolatility(settings.getVolatilityPeriod());

        ord = OrderData(
            0, 
            msg.sender, 
            address(feed),
            feed.calcLowerVolatility(vol),
            feed.calcUpperVolatility(vol),
            volume,
            volume,
            opt
        );
    }

    function findOrder(
        uint[] storage ids,
        string memory code
    )
        private
        view
        returns (OrderData memory)
    {
        for (uint i = 0; i < ids.length; i++) {
            OrderData memory ord = orders[ids[i]];
            if (compareStrings(getOptionCode(ord), code)) {
                return ord;
            }
        }
    }

    function liquidateBeforeMaturity(
        OrderData memory ord,
        string memory code,
        address token,
        uint iv
    )
        private
        returns (uint value)
    {
        uint volume = calcLiquidationVolume(ord);
        value = calcCollateral(ord.lowerVol, ord).add(iv)
            .mul(volume).div(ord.written).div(volumeBase);
        
        orders[ord.id].written = orders[ord.id].written.sub(volume);
        if (shouldRemove(ord.id)) {
            removeOrder(code, ord.id);
        }

        creditProvider.processPayment(ord.owner, token, value);
    }

    function calcLiquidationVolume(OrderData memory ord) private view returns (uint volume) {
        
        uint bal = creditProvider.balanceOf(ord.owner);
        uint collateral = calcCollateral(ord.owner);
        require(collateral > bal, "unfit for liquidation");

        volume = collateral.sub(bal).mul(volumeBase).mul(ord.written).div(
            calcCollateral(ord.upperVol.sub(ord.lowerVol), ord)
        );

        volume = MoreMath.min(volume, ord.written);
    }

    function shouldRemove(uint id) private view returns (bool) {

        return orders[id].written == 0 && orders[id].holding == 0;
    }
    
    function removeOrder(string memory code, uint id) private {
        
        Arrays.removeItem(tokensIds[code], id);
        Arrays.removeItem(book[orders[id].owner], id);
        delete orders[id];
        bookLength--;
    }

    function getOptionCode(OrderData memory ord) private view returns (string memory code) {
        
        code = string(abi.encodePacked(
            UnderlyingFeed(ord.udlFeed).getCode(),
            "-",
            "E",
            ord.option._type == OptionType.CALL ? "C" : "P",
            "-",
            MoreMath.toString(ord.option.strike),
            "-",
            MoreMath.toString(ord.option.maturity)
        ));
    }
    
    function ensureFunds(address owner) private view {
        
        require(hasRequiredCollateral(owner), "insufficient collateral");
    }
    
    function hasRequiredCollateral(address owner) private view returns (bool) {
        
        return creditProvider.balanceOf(owner) >= calcCollateral(owner);
    }
    
    function calcCollateral(uint vol, OrderData memory ord) private view returns (uint) {
        
        return (vol.mul(ord.written).mul(MoreMath.sqrt(daysToMaturity(ord)))).div(sqrtTimeBase);
    }
    
    function calcIntrinsicValue(OrderData memory ord) private view returns (int value) {
        
        OptionData memory opt = ord.option;
        int udlPrice = getUdlPrice(ord);
        int strike = int(opt.strike);

        if (opt._type == OptionType.CALL) {
            value = MoreMath.max(0, udlPrice.sub(strike));
        } else if (opt._type == OptionType.PUT) {
            value = MoreMath.max(0, strike.sub(udlPrice));
        }
    }
    
    function isValid(OrderData memory ord) private pure returns (bool) {
        
        return ord.id > 0;
    }
    
    function daysToMaturity(OrderData memory ord) private view returns (uint d) {
        
        uint _now = getUdlNow(ord);
        if (ord.option.maturity > _now) {
            d = (timeBase.mul(ord.option.maturity.sub(uint(_now)))).div(1 days);
        } else {
            d = 0;
        }
    }

    function getUdlPrice(OrderData memory ord) private view returns (int answer) {

        if (ord.option.maturity > time.getNow()) {
            (,answer) = UnderlyingFeed(ord.udlFeed).getLatestPrice();
        } else {
            (,answer) = UnderlyingFeed(ord.udlFeed).getPrice(ord.option.maturity);
        }
    }

    function getUdlNow(OrderData memory ord) private view returns (uint timestamp) {

        (timestamp,) = UnderlyingFeed(ord.udlFeed).getLatestPrice();
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}