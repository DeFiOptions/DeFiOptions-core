pragma solidity >=0.6.0;

import "../../../contracts/interfaces/AggregatorV3Interface.sol";

contract AggregatorV3Mock is AggregatorV3Interface {

    mapping(uint => uint) rounds;

    uint latestRound;
    int[] answers;
    uint[] updatedAts;

    constructor(uint[] memory _roundIds, int[] memory _answers, uint[] memory _updatedAts) public {

        for (uint i = 0; i < _roundIds.length; i++) {
            rounds[_roundIds[i]] = i;
        }
        latestRound = _roundIds[ _roundIds.length - 1];
        answers = _answers;
        updatedAts = _updatedAts;
    }

    function decimals() override external view returns (uint8) {

        return 8;
    }

    function description() override external view returns (string memory) {

    }

    function version() override external view returns (uint256) {

    }

    function getRoundData(uint80 _roundId)
        override
        external
        view
        returns
    (
        uint80 roundId,
        int256 answer,
        uint256,
        uint256 updatedAt,
        uint80
    )
    {
        roundId = _roundId;
        answer = answers[rounds[_roundId]];
        updatedAt = updatedAts[rounds[_roundId]];
    }

    function latestRoundData()
        override
        external
        view
        returns
    (
        uint80 roundId,
        int256 answer,
        uint256,
        uint256 updatedAt,
        uint80
    )
    {
        roundId = uint80(latestRound);
        answer = answers[rounds[latestRound]];
        updatedAt = updatedAts[rounds[latestRound]];
    }
}