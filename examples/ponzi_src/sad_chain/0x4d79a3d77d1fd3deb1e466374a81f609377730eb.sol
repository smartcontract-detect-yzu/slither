/**
 *Submitted for verification at Etherscan.io on 2018-10-26
*/

pragma solidity ^0.4.25;

/**
  Контракт Умножитель Народный V3: возвращает 111% от вашего депозита!
  Автоматические выплаты!
  Всего 2% на рекламу!!!
  Без ошибок, дыр, автоматический - для выплат НЕ НУЖНА администрация!
  Создан и проверен профессионалами!

  1. Пошлите любую ненулевую сумму на адрес контракта
     - сумма от 0.01 до 10 ETH
     - gas limit минимум 250000
     - вы встанете в очередь
  2. Немного подождите
  3. ...
  4. PROFIT! Вам пришло 110% от вашего депозита.

  Как это возможно?
  1. Первый инвестор в очереди (вы станете первым очень скоро) получает выплаты от
     новых инвесторов до тех пор, пока не получит 122% от своего депозита
  2. Выплаты могут приходить несколькими частями или все сразу
  3. Как только вы получаете 122% от вашего депозита, вы удаляетесь из очереди
  4. Вы можете делать несколько депозитов сразу
  5. Баланс этого контракта должен обычно быть в районе 0, потому что все поступления
     сразу же направляются на выплаты

     Таким образом, последние платят первым, и инвесторы, достигшие выплат 122% от депозита,
     удаляются из очереди, уступая место остальным

              новый инвестор --|            совсем новый инвестор --|
                 инвестор5     |                новый инвестор      |
                 инвестор4     |     =======>      инвестор5        |
                 инвестор3     |                   инвестор4        |
 (част. выплата) инвестор2    <|                   инвестор3        |
(полная выплата) инвестор1   <-|                   инвестор2   <----|  (доплата до 122%)

*/

contract MultiplierV3 {
    //Address for promo expences
    address constant private PROMO = 0x0B78927A2bdb8b61C381AfD993C93C877E4326aA;
    //Percent for promo expences
    uint constant public PROMO_PERCENT = 2; //2 for advertizing
    //How many percent for your deposit to be multiplied
    uint constant public MULTIPLIER = 111;

    //The deposit structure holds all the info about the deposit made
    struct Deposit {
        address depositor; //The depositor address
        uint128 deposit;   //The deposit amount
        uint128 expect;    //How much we should pay out (initially it is 122% of deposit)
    }

    Deposit[] private queue;  //The queue
    uint public currentReceiverIndex = 0; //The index of the first depositor in the queue. The receiver of investments!

    //This function receives all the deposits
    //stores them and make immediate payouts
    function () public payable {
        if(msg.value > 0){
            require(gasleft() >= 220000, "We require more gas!"); //We need gas to process queue
            require(msg.value <= 10 ether); //Do not allow too big investments to stabilize payouts

            //Add the investor into the queue. Mark that he expects to receive 122% of deposit back
            queue.push(Deposit(msg.sender, uint128(msg.value), uint128(msg.value*MULTIPLIER/100)));

            //Send some promo to enable this contract to leave long-long time
            uint promo = msg.value*PROMO_PERCENT/100;
            PROMO.send(promo);

            //Pay to first investors in line
            pay();
        }
    }

    //Used to pay to current investors
    //Each new transaction processes 1 - 4+ investors in the head of queue 
    //depending on balance and gas left
    function pay() private {
        //Try to send all the money on contract to the first investors in line
        uint128 money = uint128(address(this).balance);

        //We will do cycle on the queue
        for(uint i=0; i<queue.length; i++){

            uint idx = currentReceiverIndex + i;  //get the index of the currently first investor

            Deposit storage dep = queue[idx]; //get the info of the first investor

            if(money >= dep.expect){  //If we have enough money on the contract to fully pay to investor
                dep.depositor.send(dep.expect); //Send money to him
                money -= dep.expect;            //update money left

                //this investor is fully paid, so remove him
                delete queue[idx];
            }else{
                //Here we don't have enough money so partially pay to investor
                dep.depositor.send(money); //Send to him everything we have
                dep.expect -= money;       //Update the expected amount
                break;                     //Exit cycle
            }

            if(gasleft() <= 50000)         //Check the gas left. If it is low, exit the cycle
                break;                     //The next investor will process the line further
        }

        currentReceiverIndex += i; //Update the index of the current first investor
    }

    //Get the deposit info by its index
    //You can get deposit index from
    function getDeposit(uint idx) public view returns (address depositor, uint deposit, uint expect){
        Deposit storage dep = queue[idx];
        return (dep.depositor, dep.deposit, dep.expect);
    }

    //Get the count of deposits of specific investor
    function getDepositsCount(address depositor) public view returns (uint) {
        uint c = 0;
        for(uint i=currentReceiverIndex; i<queue.length; ++i){
            if(queue[i].depositor == depositor)
                c++;
        }
        return c;
    }

    //Get all deposits (index, deposit, expect) of a specific investor
    function getDeposits(address depositor) public view returns (uint[] idxs, uint128[] deposits, uint128[] expects) {
        uint c = getDepositsCount(depositor);

        idxs = new uint[](c);
        deposits = new uint128[](c);
        expects = new uint128[](c);

        if(c > 0) {
            uint j = 0;
            for(uint i=currentReceiverIndex; i<queue.length; ++i){
                Deposit storage dep = queue[i];
                if(dep.depositor == depositor){
                    idxs[j] = i;
                    deposits[j] = dep.deposit;
                    expects[j] = dep.expect;
                    j++;
                }
            }
        }
    }
    
    //Get current queue size
    function getQueueLength() public view returns (uint) {
        return queue.length - currentReceiverIndex;
    }

}