pragma solidity >=0.6.0;

import "../../../contracts/governance/Proposal.sol";

contract ChangeInterestRateProposal is Proposal {

    uint interestRate;
    uint interestRateBase;

    constructor(
        address _timeProvider,
        address _govToken,
        address _settings,
        Proposal.Quorum _quorum,
        uint expiresAt
    ) public Proposal(_timeProvider, _govToken, _settings, _quorum, expiresAt) {
        
    }

    function setInterestRate(uint ir, uint b) public {

        require(ir > 0);
        require(interestRate == 0);

        interestRate = ir;
        interestRateBase = b;
    }

    function execute(ProtocolSettings settings) public override {
        
        require(interestRate > 0, "interest rate value not set");
        settings.setDebtInterestRate(interestRate, interestRateBase);
    }
}