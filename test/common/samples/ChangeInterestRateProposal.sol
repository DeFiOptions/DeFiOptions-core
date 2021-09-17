pragma solidity >=0.6.0;

import "../../../contracts/governance/Proposal.sol";

contract ChangeInterestRateProposal is Proposal {

    uint interestRate;
    uint interestRateBase;

    function setInterestRate(uint ir, uint b) public {

        require(ir > 0);
        require(interestRate == 0);

        interestRate = ir;
        interestRateBase = b;
    }

    function getName() public override returns (string memory) {

        return "Change Debt Interest Rate";
    }

    function execute(ProtocolSettings settings) public override {
        
        require(interestRate > 0, "interest rate value not set");
        settings.setDebtInterestRate(interestRate, interestRateBase);
    }
}