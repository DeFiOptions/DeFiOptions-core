pragma solidity >=0.6.0;

import "./LinearInterpolator.sol";
import "./LiquidityPool.sol";

contract LinearLiquidityPool is LiquidityPool {
    
    LinearInterpolator private interpolator;

    string private constant _name = "Linear Liquidity Pool Redeemable Token";
    string private constant _symbol = "LLPTK";

    constructor() LiquidityPool(_name) public {
        
    }

    function initialize(Deployer deployer) override internal {

        super.initialize(deployer);
        interpolator = LinearInterpolator(deployer.getContractAddress("LinearInterpolator"));
    }

    function name() override external view returns (string memory) {
        return _name;
    }

    function symbol() override external view returns (string memory) {
        return _symbol;
    }

    function writeOptions(
        OptionToken tk,
        PricingParameters memory param,
        uint volume,
        address to
    )
        internal
        override
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
        internal
        override
        view
        returns (uint price)
    {
        uint f = op == Operation.BUY ? spread.add(fractionBase) : fractionBase.sub(spread);
        int udlPrice = getUdlPrice(p.udlFeed);
        price = interpolator.interpolate(udlPrice, p.t0, p.t1, p.x, p.y, f);
    }

    function calcVolume(
        string memory optSymbol,
        PricingParameters memory p,
        uint price,
        Operation op
    )
        internal
        override
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
}