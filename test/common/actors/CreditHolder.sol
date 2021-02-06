pragma solidity >=0.6.0;

import "../../../contracts/finance/CreditToken.sol";
import "../../../contracts/deployment/ManagedContract.sol";

contract CreditHolder is ManagedContract {
    
    CreditToken creditToken;
    address addr;
    
    constructor() public {
        addr = address(uint160(address(this)));
    }

    function setCreditToken(address _creditToken) public {

        creditToken = CreditToken(_creditToken);
    }

    function issueTokens(address to, uint amount) public {

        creditToken.issue(to, amount);
    }

    function transfer(address to, uint amount) public {

        creditToken.transfer(to, amount);
    }

    function requestWithdraw(uint value) public {

        creditToken.requestWithdraw(value);
    }
}