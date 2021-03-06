// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
* @title RewardsPool Contract
* @author alexponce.eth
* @notice A contract that allows user to farm SimpleToken rewards based on contributions to the pool
 */
contract RewardsPool is Ownable {

    // SimpleToken interface
    IERC20 private _token;

    // Participants that have contributed
    address[] participants;
    
    // Current total tokens added to the contract as rewards
    uint256 totalRewards;

    // Precision
    uint256 e18 = 18;

    // Participant flag and index in participants
    struct Participant {
        bool isParticipant;
        uint256 participantIndex;
    }
    
    // address to Participant information
    mapping(address => Participant) participant;

    // funds participant will receive when they withdraw
    mapping(address => uint256) public participantDeposit;

    // rewards participant will receive when they withdraw
    mapping(address => uint256) public participantReward;

    // RewardsPool SimpleToken
    constructor (IERC20 token) {
        _token = token;        
    }

    // RewardsPool Events
    event DepositAdded(address indexed _to, uint256 _deposit);
    event RewardAdded(address indexed _to, uint256 _reward);
    event ParticipantAdded(address indexed _participating);
    event ParticipantRemoved(address indexed _removed);


    /**
    * @notice RewardsPool method to deposit funds to the pool
    */
    function deposit() public payable {
        addParticipant(msg.sender);
        participantDeposit[msg.sender] += msg.value;
        emit DepositAdded(msg.sender, msg.value);
    }

    /**
    * @notice RewardsPool method to withdraw participant funds and rewards
    */
    function withdraw() public {
        require(participantDeposit[msg.sender] > 0, "No funds to withdraw");
        uint userDeposit = participantDeposit[msg.sender];
        participantDeposit[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: userDeposit}("");
        require(sent, "Failed to return Deposit");
        uint userReward = participantReward[msg.sender];
        participantReward[msg.sender] = 0;
        bool sentReward = _token.transfer(msg.sender, userReward);
        require(sentReward, "Failed to send participant token reward");
        removeParticipant(msg.sender);
    }

    /**
    * @notice RewardsPool method to add SimpleToken rewards to the pool
    * @param _rewards to be added to RewardsPool Contract
    */
    function addRewards(uint256 _rewards) external payable onlyOwner{
        address from = msg.sender;
        (bool poolRewards) = _token.transferFrom(from, address(this), _rewards);
        require(poolRewards, "Failed to add rewards to pool");
        totalRewards += _rewards;
        uint numofParticipants = participants.length;
        for (uint i = 0; i < numofParticipants; i++) {
            address _participant = participants[i];
            uint256 _ratio = calculateRatio(participantDeposit[_participant], address(this).balance);
            uint256 _participantrewards = calculateRewards(_rewards, _ratio);
            participantReward[_participant] += _participantrewards;
            emit RewardAdded(_participant, _participantrewards);
        }
    }
    
    /**
    * @notice RewardsPool method to track participating address in the pool
    * @param _addr of participant to be added if not participating
    */
    function addParticipant(address _addr) internal {
        if (participant[_addr].isParticipant) {
            return;
        } else {
            uint index = participants.length;
            participant[_addr].participantIndex = index;
            participants.push(_addr);
            participant[_addr].isParticipant = true;
            emit ParticipantAdded(_addr);
        }
    }

    /**
    * @notice RewardsPool method to remove participant from pool
    * @param _addr of participant to be removed if participating
    */
    function removeParticipant(address _addr) internal {
        if (!participant[_addr].isParticipant) {
            return;
        } else {
            participant[_addr].isParticipant = false;
            uint index = participant[_addr].participantIndex;
            uint lastIndex = participants.length - 1;
            address lastKey = participants[lastIndex];
            participant[lastKey].participantIndex = index;
            delete participant[_addr].participantIndex;
            participants.pop();
            emit ParticipantRemoved(_addr);
        }
    }

    /**
    * @notice RewardsPool method to check current ratio externally
    * @param _addr address to check if deposited funds will get rewards when added
    */

    function currentRatio(address _addr) external view returns (uint256) {
        require (participant[_addr].isParticipant == true, "Not a participating address");
        return calculateRatio(participantDeposit[_addr], address(this).balance);
    }

    /**
    * @notice RewardsPool method to calculate percentage of funds in pool
    * @param _deposit funds to be calculated
    * @param _totalDeposit current total funds in the pool
    */
    function calculateRatio(uint256 _deposit, uint256 _totalDeposit) internal view returns(uint256 ratio) {
        ratio = (_deposit * (10 ** e18)) / _totalDeposit;
    }

    /**
    * @notice RewardsPool method to calculate rewards based on percentage
    * @param _rewards total rewards to be distributed
    * @param _ratio percentage of total rewards to be calculated
    */
    function calculateRewards(uint256 _rewards, uint256 _ratio) internal view returns(uint256 participantRewards) {
        participantRewards = (_rewards * _ratio) / (10 ** e18);
    }
}