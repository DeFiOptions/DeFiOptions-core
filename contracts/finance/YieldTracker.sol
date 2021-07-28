pragma solidity ^0.6.0;

import "../deployment/Deployer.sol";
import "../deployment/ManagedContract.sol";
import "../finance/OptionsExchange.sol";
import "../interfaces/TimeProvider.sol";
import "../utils/SafeCast.sol";
import "../utils/SafeMath.sol";
import "../utils/SignedSafeMath.sol";

contract YieldTracker is ManagedContract {

    using SafeCast for uint;
    using SafeMath for uint;
    using SignedSafeMath for int;

    struct Deposit {
        uint32 date;
        int balance;
        int value;
    }
    
    TimeProvider private time;
    OptionsExchange private exchange;

    mapping(address => Deposit[]) private deposits;

    uint private fractionBase;

    function initialize(Deployer deployer) override internal {
        
        time = TimeProvider(deployer.getContractAddress("TimeProvider"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        fractionBase = 1e9;
    }

    function push(int balance, int value) external {

        push(time.getNow().toUint32(), balance, value);
    }

    function push(uint32 date, int balance, int value) public {

        deposits[msg.sender].push(
            Deposit(date, balance, value)
        );
    }

    function yield(address target, uint dt) external view returns (uint y) {
        
        y = fractionBase;

        Deposit[] memory _deposits = deposits[target];

        if (_deposits.length > 0) {
            
            uint _now = time.getNow();
            uint start = _now.sub(dt);
            
            uint i = 0;
            for (i = 0; i < _deposits.length; i++) {
                if (_deposits[i].date > start) {
                    break;
                }
            }

            for (; i <= _deposits.length; i++) {
                if (i > 0) {
                    y = y.mul(
                        calcYield(target, _deposits, i, start)
                    ).div(fractionBase);
                }
            }
        }
    }

    function calcYield(
        address target,
        Deposit[] memory _deposits,
        uint index,
        uint start
    )
        private
        view
        returns (uint y)
    {
        uint t0 = _deposits[index - 1].date;
        uint t1 = index < _deposits.length ?
            _deposits[index].date : time.getNow();

        int v0 = _deposits[index - 1].value.add(_deposits[index - 1].balance);
        int v1 = index < _deposits.length ? 
            int(_deposits[index].balance) :
            exchange.calcExpectedPayout(target).add(int(exchange.balanceOf(target)));

        y = uint(v1.mul(int(fractionBase)).div(v0));
        if (start > t0) {
            y = MoreMath.powDecimal(
                y, 
                (t1.sub(start)).mul(fractionBase).div(t1.sub(t0)), 
                fractionBase
            );
        }
    }
}