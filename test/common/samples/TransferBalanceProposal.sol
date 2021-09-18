pragma solidity >=0.6.0;

import "../../../contracts/governance/Proposal.sol";

contract TransferBalanceProposal is Proposal {

    uint amount;

    function setAmount(uint _amount) public {

        require(_amount > 0);

        amount = _amount;
    }

    function getName() public override returns (string memory) {

        return "Transfer Balance";
    }

    function execute(ProtocolSettings settings) public override {
        
        require(amount > 0, "amount not set");
        settings.transferBalance(address(this), amount);
    }
}