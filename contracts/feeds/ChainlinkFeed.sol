pragma solidity >=0.6.0;

import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/TimeProvider.sol";
import "../interfaces/UnderlyingFeed.sol";
import "../utils/MoreMath.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract ChainlinkFeed is UnderlyingFeed {

    using SafeMath for uint;
    using SignedSafeMath for int;

    struct Sample {
        uint timestamp;
        int price;
    }

    AggregatorV3Interface private aggregator;
    TimeProvider private time;

    mapping(uint => Sample) private dailyPrices;
    mapping(uint => mapping(uint => uint)) private dailyVolatilities;

    string private _symbol;
    Sample[] private samples;
    uint private offset;
    int private priceN;
    int private priceD;

    constructor(
        string memory _sb,
        address _aggregator,
        address _time,
        uint _offset,
        uint[] memory _timestamps,
        int[] memory _prices
    )
        public
    {
        _symbol = _sb;
        aggregator = AggregatorV3Interface(_aggregator);
        time = TimeProvider(_time);
        offset = _offset;
        initialize(_timestamps, _prices);
    }

    function initialize(uint[] memory _timestamps, int[] memory _prices) public {

        require(samples.length == 0, "already initialized");

        int exchangeDecimals = 18;
        int diff = exchangeDecimals.sub(int(aggregator.decimals()));
        require(-18 <= diff && diff <= 18, "invalid decimals");
        if (diff > 0) {
            priceN = int(10 ** uint(diff));
            priceD = 1;
        } else {
            priceN = 1;
            priceD = int(10 ** uint(-diff));
        }

        for (uint i = 0; i < _timestamps.length; i++) {

            uint ts = _timestamps[i];
            int pc = _prices[i];
            Sample memory s = Sample(ts, rescalePrice(pc));

            if (ts.mod(1 days) == 0) {
                dailyPrices[ts] = s;
            }
            
            samples.push(s);
        }
    }

    function initializeDecimals() private {

    }

    function symbol() override external view returns (string memory) {

        return _symbol;
    }

    function getLatestPrice() override external view returns (uint timestamp, int price) {

        (, price,, timestamp,) = aggregator.latestRoundData();
        price = rescalePrice(price);
    }

    function getPrice(uint position) 
        override
        external
        view
        returns (uint timestamp, int price)
    {
        (timestamp, price,) = getPriceCached(position);
    }

    function getPriceCached(uint position)
        public
        view
        returns (uint timestamp, int price, bool cached)
    {
        if ((position.mod(1 days) == 0) && (dailyPrices[position].timestamp != 0)) {

            timestamp = position;
            price = dailyPrices[position].price;
            cached = true;

        } else {

            uint len = samples.length;

            require(len > 0, "no sample");

            require(
                samples[0].timestamp <= position && samples[len - 1].timestamp >= position,
                string(abi.encodePacked("invalid position: ", MoreMath.toString(position)))
            );

            uint start = 0;
            uint end = len - 1;

            while (true) {
                uint m = (start.add(end).add(1)).div(2);
                Sample memory s = samples[m];

                if (s.timestamp > position)
                    end = m;
                else
                    start = m;

                if ((s.timestamp == position) || (end == m)) {
                    timestamp = s.timestamp;
                    price = s.price;
                    break;
                }
            }
        }
    }

    function getDailyVolatility(uint timespan) override external view returns (uint vol) {

        (vol, ) = getDailyVolatilityCached(timespan);
    }

    function getDailyVolatilityCached(uint timespan) public view returns (uint vol, bool cached) {

        uint period = timespan.div(1 days);
        timespan = period.mul(1 days);
        int[] memory array = new int[](period - 1);

        if (dailyVolatilities[timespan][today()] == 0) {

            int prev;
            int pBase = 1e9;

            for (uint i = 0; i < period; i++) {
                uint position = today().sub(timespan).add(i.add(1).mul(1 days));
                (, int price,) = getPriceCached(position);
                if (i > 0) {
                    array[i.sub(1)] = price.mul(pBase).div(prev);
                }
                prev = price;
            }

            vol = MoreMath.std(array).mul(uint(prev)).div(uint(pBase));

        } else {

            vol = decodeValue(dailyVolatilities[timespan][today()]);
            cached = true;

        }
    }

    function calcLowerVolatility(uint vol) override external view returns (uint lowerVol) {

        lowerVol = vol.mul(3).div(2);
    }

    function calcUpperVolatility(uint vol) override external view returns (uint upperVol) {

        upperVol = vol.mul(3);
    }

    function prefetchSample() external {

        (, int price,, uint timestamp,) = aggregator.latestRoundData();
        price = rescalePrice(price);
        require(timestamp > samples[samples.length - 1].timestamp, "already up to date");
        samples.push(Sample(timestamp, price));
    }

    function prefetchDailyPrice(uint roundId) external {

        int price;
        uint timestamp;

        if (roundId == 0) {
            (, price,, timestamp,) = aggregator.latestRoundData();
        } else {
            (, price,, timestamp,) = aggregator.getRoundData(uint80(roundId));
        }
        price = rescalePrice(price);

        uint key = timestamp.div(1 days).mul(1 days);
        Sample memory s = Sample(timestamp, price);

        require(
            dailyPrices[key].timestamp == 0 || dailyPrices[key].timestamp > s.timestamp,
            "price already set"
        );
        dailyPrices[key] = s;

        if (samples.length == 0 || samples[samples.length - 1].timestamp < timestamp) {
            samples.push(s);
        }
    }

    function prefetchDailyVolatility(uint timespan) external {

        require(timespan.mod(1 days) == 0, "invalid timespan");

        if (dailyVolatilities[timespan][today()] == 0) {
            (uint vol, bool cached) = getDailyVolatilityCached(timespan);
            require(!cached, "already cached");
            dailyVolatilities[timespan][today()] = encodeValue(vol);
        }
    }

    function rescalePrice(int price) private view returns (int) {

        return price.mul(priceN).div(priceD);
    }

    function encodeValue(uint v) private pure returns (uint) {
        return v | (uint(1) << 255);
    }

    function decodeValue(uint v) private pure returns (uint) {
        return v & (~(uint(1) << 255));
    }

    function today() private view returns(uint) {

        return time.getNow().sub(offset).div(1 days).mul(1 days);
    }
}