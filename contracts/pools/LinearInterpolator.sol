pragma solidity >=0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract LinearInterpolator is ManagedContract {

    using SafeMath for uint;
    using SignedSafeMath for int;
    
    TimeProvider private time;

    uint private fractionBase;

    function initialize(Deployer deployer) override internal {
        
        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        fractionBase = 1e9;
    }

    function interpolate(
        int udlPrice,
        uint32 t0,
        uint32 t1,
        uint120[] calldata x,
        uint120[] calldata y,
        uint f
    )
        external
        view
        returns (uint price)
    {
        (uint j, uint xp) = findUdlPrice(udlPrice, x);

        uint _now = time.getNow();
        uint dt = uint(t1).sub(uint(t0));
        require(_now >= t0 && _now <= t1, "invalid pricing parameters");
        
        uint t = _now.sub(t0);
        uint p0 = calcOptPriceAt(x, y, 0, j, xp);
        uint p1 = calcOptPriceAt(x, y, x.length, j, xp);

        price = p0.mul(dt);
        price = p0 > p1 ? price.sub(t.mul(p0.sub(p1))) : price.add(t.mul(p1.sub(p0)));
        price = price.mul(f).div(fractionBase).div(dt);
    }

    function findUdlPrice(
        int udlPrice,
        uint120[] memory x
    )
        private
        pure
        returns (uint j, uint xp)
    {        
        j = 0;
        xp = uint(udlPrice);
        while (x[j] < xp && j < x.length) {
            j++;
        }
        require(j > 0 && j < x.length, "invalid pricing parameters");
    }

    function calcOptPriceAt(
        uint120[] memory x,
        uint120[] memory y,
        uint offset,
        uint j,
        uint xp
    )
        private
        pure
        returns (uint price)
    {
        uint k = offset.add(j);
        int yA = int(y[k]);
        int yB = int(y[k - 1]);
        price = uint(
            yA.sub(yB).mul(
                int(xp.sub(x[j - 1]))
            ).div(
                int(x[j]).sub(int(x[j - 1]))
            ).add(yB)
        );
    }
}