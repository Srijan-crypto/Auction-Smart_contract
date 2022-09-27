// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Auction{
    address payable public immutable auctioneer;//payable as auctioneer gets the highestPayableBid
    uint public stblock; //start time block
    uint public etblock; //end time block
    enum State{
        Started,
        Running,
        Ended,
        Cancelled
    }
    State public auctionState; //enum type variable

    uint public highestPayableBid; //current bid must be more than highestPayableBid
    uint public minBidInc; //minimum bid increment

    address payable public highestBidder;//payable as he has to pay highestbid - HPB
    mapping (address=>uint) public bids;//to store all the bids

    constructor(){
        auctioneer = payable(msg.sender);
        auctionState = State.Running;//consider the auction to be running
        stblock = block.number; // OR stblock = block.timestamp;
        etblock = stblock+240;//(240 because for 1 hour) OR etblock = stblock+ 1 hour;
        // 15sec -> 1block  =>  60min -> 240block;
        minBidInc = 1 ether;
    }// here our auction will work for 1 hour

    modifier notOwner(){
        require(msg.sender!=auctioneer,"Auctioneer cannot bid");
        _;
    }
    modifier owner(){
        require(msg.sender==auctioneer,"Only auctioneer can do it");
        _;
    }
    modifier Started(){
        require(block.number>stblock,"");
        _;
    }
    modifier notEnded(){
        require(block.number<etblock,"");
        _;
    }

    function cancelAuc() public owner{ // only owner can cancel the function
        auctionState = State.Cancelled;
    }

/*    function endAuc() public owner{  //if you want to manually end the auction
        auctionState = State.Ended;
    } 
*/

    function min(uint a,uint b) private pure returns(uint){//to find min of 2 numbers
        if(a<=b)
            return a;
        return b;
    }

    function bid() payable public notOwner Started notEnded{ //payable as msg.value is used
        require(auctionState == State.Running);
        require(msg.value>=minBidInc);
// each person will bid after the previous one is done
        uint currentBid = bids[msg.sender] + msg.value;//previous bid + msg.value
        require(currentBid>highestPayableBid);

        bids[msg.sender] = currentBid;//updating the bids of msg.sender
        if(currentBid<bids[highestBidder])//here highest bidder is the same
            highestPayableBid = min(currentBid+minBidInc,bids[highestBidder]);//formula
        else{
            highestPayableBid = min(currentBid,bids[highestBidder]+minBidInc);//formula
            highestBidder = payable(msg.sender);//here highest bidder is changed
        }
    }

    function finalizeAuc() public{// each bidder has to do finalizeAuc to get their ethers back
        require(auctionState==State.Cancelled || block.number>etblock);//cancelled or ended
        //auction stands cancelled if aunctionState=cancelled and ended if block.number>etblock
        require(msg.sender == auctioneer || bids[msg.sender]>0); 
        //only the auctioneer and the people who have bidded can finalize the auction

        address payable recepient;
        uint value;
        if(auctionState==State.Cancelled){//if  auction cancelled
            recepient = payable(msg.sender);
            value = bids[msg.sender];
        }
        else{ // if auction ended : auctioneer ended or bidder ended
            if(msg.sender == auctioneer){ //auctioneer ended the auction
                recepient = auctioneer;
                value = highestPayableBid;//auctioneer gets the highestpayablebid
            }
            else{ //bidder ended the auction: highestBidder ended or normal bidder ended
                if(msg.sender == highestBidder){//highestBidder ended the auction
                    recepient = highestBidder;//highestBidder gets back highestBid - HPB
                    value = bids[highestBidder] - highestPayableBid;
                }
                else{//normal bidder ended the auction 
                    recepient = payable(msg.sender);
                    value = bids[msg.sender];//normal bidder gets back his/her bidded value
                }
            }
        }

        bids[msg.sender] = 0;//so that if once they have finalized ,they cannot do it again

        (bool state,) = recepient.call{value:value}("");// sending ethers using call()
        require(state == true,"Failed transaction");
    }
}

//if you want to check now by ending the auction you cannot manually do it in the above smart
//contract as it will last for 1 hour. If you want to end it manually then,add an OR(||) condition
//in the 1st require part i.e.(... || auctionState == State.Ended || ...) and create an endAuc()
//function to manually end the auction like we made a function to cancel auction i.e. cancelAuc()