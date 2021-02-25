pragma solidity >=0.6.0;

import "../deployment/ManagedContract.sol";
import "../finance/OptionsExchange.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/LiquidityPool.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/ERC20.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract LinearLiquidityPool is LiquidityPool, ManagedContract, ERC20 {

    using SafeMath for uint;
    using SignedSafeMath for int;

    enum Operation { BUY, SELL }

    struct PricingParameters {
        address udlFeed;
        uint strike;
        uint maturity;
        OptionsExchange.OptionType optType;
        uint t0;
        uint[] x;
        uint[] y;
    }

    TimeProvider private time;
    OptionsExchange private exchange;

    mapping(string => PricingParameters) private parameters;
    mapping(string => uint) private buyStock;
    mapping(string => uint) private sellStock;

    address private owner;
    address[] private holders;
    uint private spread;
    uint private reserveRatio;
    uint private maturity;

    uint timeBase;
    uint sqrtTimeBase;
    uint volumeBase;
    uint fractionBase;

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
        fractionBase = 1e6;
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

    function addCode(
        string calldata code,
        address udlFeed,
        uint strike,
        uint _maturity,
        OptionsExchange.OptionType optType,
        uint t0,
        uint[] calldata x,
        uint[] calldata y,
        uint _buyStock,
        uint _sellStock
    )
        external
    {
        ensureCaller();
        require(_maturity < maturity, "invalid maturity");
        parameters[code] = PricingParameters(udlFeed, strike, _maturity, optType, t0, x, y);
        buyStock[code] = _buyStock;
        sellStock[code] = _sellStock;
        emit AddCode(code);
    }
    
    function removeCode(string calldata code) external {

        ensureCaller();
        PricingParameters memory empty;
        parameters[code] = empty;
        delete buyStock[code];
        delete sellStock[code];
        emit RemoveCode(code);
    }

    function depositTokens(address to, address token, uint value) override external {

        uint b0 = exchange.balanceOf(to);
        depositTokensInExchange(address(this), token, value);
        uint b1 = exchange.balanceOf(to);
        int expBal = exchange.calcExpectedPayout(address(this)).add(
            int(exchange.balanceOf(address(this)))
        );
        uint v = b1.sub(b0).mul(_totalSupply).div(uint(expBal));
        addBalance(to, v);
    }

    function destroy() external {

        require(maturity < time.getNow(), "unfit for destruction");

        uint valTotal = exchange.balanceOf(address(this));
        uint valRemaining = valTotal;
        
        for (uint i = 0; i < holders.length && valRemaining > 0; i++) {

            uint bal = balanceOf(holders[i]);
            
            if (bal > 0) {
                uint valTransfer = valTotal.mul(bal).div(_totalSupply);
                exchange.transferBalance(holders[i], valTransfer);
                valRemaining = valRemaining.sub(valTransfer);
                removeBalance(holders[i], bal);
            }
        }

        if (valRemaining > 0) {
            exchange.transferBalance(msg.sender, valRemaining);
        }
        selfdestruct(msg.sender);
    }

    function queryBuy(string memory code)
        override
        public
        view
        returns (uint price, uint volume)
    {
        ensureValidCode(code);
        PricingParameters memory p = parameters[code];
        price = calcOptPrice(p, Operation.BUY);
        volume = MoreMath.min(calcVolume(p, price, Operation.BUY), buyStock[code]);
    }

    function querySell(string memory code)
        override
        public
        view
        returns (uint price, uint volume)
    {    
        ensureValidCode(code);
        PricingParameters memory p = parameters[code];
        price = calcOptPrice(p, Operation.SELL);
        volume = MoreMath.min(calcVolume(p, price, Operation.SELL), sellStock[code]);
    }

    function buy(string calldata code, uint price, uint volume, address token) override external {

        ensureValidCode(code);

        PricingParameters memory param = parameters[code];
        uint p = calcOptPrice(param, Operation.BUY);
        require(price >= p, "insufficient price");

        uint value = p.mul(volume).div(volumeBase);
        depositTokensInExchange(address(this), token, value);

        uint id = exchange.writeOptions(
            param.udlFeed,
            volume,
            param.optType,
            param.strike,
            param.maturity
        );
        require(
            volume <= buyStock[code] || calcFreeBalance() > 0,
            "excessive volume"
        );

        address addr = exchange.resolveToken(id);
        OptionToken tk = OptionToken(addr);
        tk.transfer(msg.sender, volume);
    }

    function sell(string calldata code, uint price, uint volume) override external {

        ensureValidCode(code);

        PricingParameters memory param = parameters[code];
        uint p = calcOptPrice(param, Operation.SELL);
        require(price <= p, "insufficient price");

        address addr = exchange.resolveToken(code);
        OptionToken tk = OptionToken(addr);
        tk.transferFrom(msg.sender, address(this), volume);

        uint value = p.mul(volume).div(volumeBase);
        exchange.transferBalance(msg.sender, value);
        
        require(
            volume <= sellStock[code] || calcFreeBalance() > 0,
            "excessive volume"
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
        require(_now >= p.t0 && _now <= p.t0.add(1 days), "invalid pricing parameters");
        uint t = _now.sub(_now.div(1 days).mul(1 days));
        uint p0 = calcOptPriceAt(p, 0, j, xp);
        uint p1 = calcOptPriceAt(p, p.x.length, j, xp);

        price = p0.mul(1 days).sub(
            t.mul(p0.sub(p1))
        ).mul(f).div(fractionBase).div(1 days);
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
        uint k = offset + j;
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
        uint coll = exchange.calcCollateral(
            p.udlFeed,
            volumeBase,
            p.optType,
            p.strike,
            p.maturity
        );

        if (op == Operation.BUY) {
            volume = coll <= price ? uint(-1) :
                calcFreeBalance().mul(volumeBase).div(coll.sub(price));
        } else {
            volume = price <= coll ? uint(-1) :
                calcFreeBalance().mul(volumeBase).div(price.sub(coll));
        }
    }

    function calcFreeBalance() private view returns (uint balance) {

        balance = exchange.balanceOf(address(this)).mul(reserveRatio).div(fractionBase);
        balance = exchange.calcSurplus(address(this)).sub(balance);
    }

    function depositTokensInExchange(address to, address token, uint value) private {

        ERC20 t = ERC20(token);
        t.transferFrom(msg.sender, address(this), value);
        t.approve(address(exchange), value);
        exchange.depositTokens(to, token, value);
    }

    function addBalance(address _owner, uint value) override internal {

        if (balanceOf(_owner) == 0) {
            holders.push(_owner);
        }
        balances[_owner] = balanceOf(_owner).add(value);
    }

    function ensureValidCode(string memory code) private view {

        require(parameters[code].udlFeed !=  address(0), "invalid code");
    }

    function ensureCaller() private view {

        require(owner == address(0) || msg.sender == owner, "unauthorized caller");
    }
}