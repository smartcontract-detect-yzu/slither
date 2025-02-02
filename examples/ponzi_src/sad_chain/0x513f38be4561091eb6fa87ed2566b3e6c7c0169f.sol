/**
 *Submitted for verification at Etherscan.io on 2019-06-14
*/

pragma solidity 0.5.9;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address payable public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }


    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address payable newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address payable newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract Distripto is Ownable {

    using SafeMath for uint256;

    uint public minDeposit = 10000000000000000; // 0.01 eth
    uint public maxDeposit = 1000000000000000000; // 1 eth
    uint public minDistribute = 2 ether;
    uint public currentPaymentIndex;
    uint public amountForDistribution;
    uint public percent = 120;

    uint public lastWinnerPeriod = 12 hours;

    uint public amountRaised;
    uint public depositorsCount;

    address payable promoWallet;

    struct Deposit {
        address payable depositor;
        uint amount;
        uint payout;
        uint depositTime;
        uint paymentTime;
    }

    // list of all deposites
    Deposit[] public deposits;
    // list of user deposits
    mapping (address => uint[]) public depositors;

    event OnDepositReceived(address investorAddress, uint value);
    event OnPaymentSent(address investorAddress, uint value);


    constructor () public {
        promoWallet = msg.sender;
    }


    function () external payable {
        if (msg.value > 0) {
            makeDeposit();
        } else {
            distributeLast();
            distribute(0);
        }
    }


    function makeDeposit() internal {
        require (msg.value >= minDeposit && msg.value <= maxDeposit);

        if (deposits.length > 0 && deposits[deposits.length - 1].depositTime + lastWinnerPeriod < now) {
            distributeLast();
        }

        Deposit memory newDeposit = Deposit(msg.sender, msg.value, msg.value.mul(percent).div(100), now, 0);
        deposits.push(newDeposit);

        if (depositors[msg.sender].length == 0) depositorsCount += 1;

        depositors[msg.sender].push(deposits.length - 1);
        amountForDistribution = amountForDistribution.add(msg.value);

        amountRaised = amountRaised.add(msg.value);

        emit OnDepositReceived(msg.sender, msg.value);
    }


    function distributeLast() public  {
        if(deposits.length > 0 && deposits[deposits.length - 1].depositTime + lastWinnerPeriod < now) {
            uint val = deposits[deposits.length - 1].amount.mul(10).div(100);
            if (address(this).balance >= deposits[deposits.length - 1].payout + val) {
                if (deposits[deposits.length - 1].paymentTime == 0) {
                    deposits[deposits.length - 1].paymentTime = now;
                    promoWallet.transfer(val);
                    deposits[deposits.length - 1].depositor.send(deposits[deposits.length - 1].payout);
                    emit OnPaymentSent(deposits[deposits.length - 1].depositor, deposits[deposits.length - 1].payout);
                }
            }
        }
    }


    function distribute(uint _iterations) public  {
        if (address(this).balance >= minDistribute) {
            promoWallet.transfer(amountForDistribution.mul(10).div(100));

            _iterations = _iterations == 0 ? deposits.length : _iterations;

            for (uint i = currentPaymentIndex; i < _iterations && address(this).balance >= deposits[i].payout; i++) {
                if (deposits[i].paymentTime == 0) {
                    deposits[i].paymentTime = now;
                    deposits[i].depositor.send(deposits[i].payout);
                    emit OnPaymentSent(deposits[i].depositor, deposits[i].payout);
                }

                currentPaymentIndex += 1;
            }

            amountForDistribution = 0;
        }
    }


    function getDepositsCount() public view returns (uint) {
        return deposits.length;
    }

    function lastDepositId() public view returns (uint) {
        return deposits.length - 1;
    }

    function getDeposit(uint _id) public view returns (address, uint, uint, uint, uint){
        return (deposits[_id].depositor, deposits[_id].amount, deposits[_id].payout,
        deposits[_id].depositTime, deposits[_id].paymentTime);
    }

    function getUserDepositsCount(address depositor) public view returns (uint) {
        return depositors[depositor].length;
    }

    // lastIndex from the end of payments lest (0 - last payment), returns: address of depositor, payment time, payment amount
    function getLastPayments(uint lastIndex) public view returns (address, uint, uint, uint, uint) {
        uint depositIndex = currentPaymentIndex.sub(lastIndex + 1);

        return (deposits[depositIndex].depositor,
        deposits[depositIndex].amount,
        deposits[depositIndex].payout,
        deposits[depositIndex].depositTime,
        deposits[depositIndex].paymentTime);
    }

    function getUserDeposit(address depositor, uint depositNumber) public view returns(uint, uint, uint, uint) {
        return (deposits[depositors[depositor][depositNumber]].amount,
        deposits[depositors[depositor][depositNumber]].payout,
        deposits[depositors[depositor][depositNumber]].depositTime,
        deposits[depositors[depositor][depositNumber]].paymentTime);
    }


    function setNewMinDeposit(uint newMinDeposit) public onlyOwner {
        minDeposit = newMinDeposit;
    }

    function setNewMaxDeposit(uint newMaxDeposit) public onlyOwner {
        maxDeposit = newMaxDeposit;
    }

    function setPromoWallet(address payable newPromoWallet) public onlyOwner {
        require (newPromoWallet != address(0));
        promoWallet = newPromoWallet;
    }
}