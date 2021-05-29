pragma solidity >=0.6.0;

import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/deployment/ManagedContract.sol";
import "../../../contracts/interfaces/TimeProvider.sol";
import "../../../contracts/interfaces/UnderlyingFeed.sol";

contract EthFeedMock is ManagedContract, UnderlyingFeed {
    
    TimeProvider private time;
    int ethPrice = 550e18;
    address underlying;

    function initialize(Deployer deployer) override internal {

        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        underlying = deployer.getContractAddress("UnderlyingToken");
    }

    function symbol() override external view returns (string memory) {

        return "ETHM";
    }

    function getUnderlyingAddr() override external view returns (address) {

        return underlying;
    }
    
    function getPrice() external view returns (int) {
        return ethPrice;
    }
    
    function setPrice(int _ethPrice) public {
        ethPrice = _ethPrice;
    }
    
    function getLatestPrice() override external view returns (uint timestamp, int price) {
        timestamp = time.getNow();
        price = ethPrice;
    }
    
    function getPrice(uint) override external view returns (uint timestamp, int price) {
        timestamp = time.getNow();
        price = ethPrice;
    }

    function getDailyVolatility(uint) override external view returns (uint value) {

        value = 1375e16; 
    }

    function calcLowerVolatility(uint vol) override external view returns (uint lowerVol) {

        lowerVol = vol * 4;
    }

    function calcUpperVolatility(uint vol) override external view returns (uint upperVol) {

        upperVol = vol * 5;
    }
}