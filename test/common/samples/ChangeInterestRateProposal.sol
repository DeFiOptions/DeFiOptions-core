pragma solidity >=0.6.0;

import "../../../contracts/governance/Proposal.sol";
import "../../../contracts/governance/ProtocolSettings.sol";

contract ChangeInterestRateProposal is Proposal {

    ProtocolSettings settings;

    uint interestRate;
    uint interestRateBase;

    constructor(
        address _timeProvider,
        address _settings,
        address _govToken,
        Proposal.Quorum _quorum,
        uint expiresAt
    ) public Proposal(_timeProvider, _govToken, _quorum, expiresAt) {
        settings = ProtocolSettings(_settings);
    }

    function setInterestRate(uint ir, uint b) public {

        require(ir > 0);
        require(interestRate == 0);

        interestRate = ir;
        interestRateBase = b;
    }

    function execute() public override {
        
        require(interestRate > 0, "interest rate value not set");
        settings.setDebtInterestRate(interestRate, interestRateBase);
    }
}