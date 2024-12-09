// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKaineStaking} from "./interfaces/IKaineStaking.sol";

contract KaineStaking is IKaineStaking, Ownable, ReentrancyGuard, Pausable {
    IERC20 public stakingToken;

    struct PoolInfo {
        uint256 totalStaked;
        uint256 totalReward;
        uint256 apy;
        uint256 penaltyFee;
        uint64 lockDay;
        uint256 numberOfStakers;
    }

    struct UserStake {
        uint256 stakedAmount;
        uint256 reward;
        uint64 stakeTime;
        uint64 unlockTime;
        uint64 claimDate;
        uint8 stakingType;
    }

    PoolInfo[3] public pools;
    uint256 public itemIdCounter;
    mapping(uint256 => UserStake) public userStakes;
    mapping(address => uint256[]) public userItems;
    mapping(uint256 => address) public itemOwner;

    event Stake(
        address indexed user,
        uint256 indexed itemId,
        uint256 amount,
        uint256 reward,
        uint64 stakeTime,
        uint64 claimDate,
        uint8 stakingType
    );
    event Unstake(address indexed user, uint256 indexed itemId, uint256 amount, uint256 penalty, uint64 unstakeTime);
    event ClaimRewardStaking(address indexed user, uint256 indexed itemId, uint256 reward, uint64 claimTime);

    constructor(address _stakingToken, uint256 _penaltyFee) {
        stakingToken = IERC20(_stakingToken);
        // penalty fee should be 0.06
        pools[0] = PoolInfo(0, 0, 5, _penaltyFee, 14 days, 0);
        pools[1] = PoolInfo(0, 0, 10, _penaltyFee, 30 days, 0);
        pools[2] = PoolInfo(0, 0, 45, _penaltyFee, 90 days, 0);
    }

    modifier validItem(uint256 _itemId) {
        require(itemOwner[_itemId] == msg.sender, "Invalid itemId or staker");
        _;
    }

    function stake(uint256 _amount, uint8 _stakingType) external override whenNotPaused nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(_stakingType >= 1 && _stakingType <= 3, "Invalid staking type");

        PoolInfo storage pool = pools[_stakingType - 1];
        stakingToken.transferFrom(msg.sender, address(this), _amount);

        itemIdCounter += 1;
        uint256 newItemId = itemIdCounter;

        uint256 reward = (_amount * pool.apy) / 100;
        uint64 unlockTime = uint64(block.timestamp + pool.lockDay);
        uint64 claimDate = unlockTime; // Set claim date as the unlock time

        UserStake memory newUserStake = UserStake({
            stakedAmount: _amount,
            reward: reward,
            stakeTime: uint64(block.timestamp),
            unlockTime: unlockTime,
            claimDate: claimDate,
            stakingType: _stakingType
        });

        userStakes[newItemId] = newUserStake;
        itemOwner[newItemId] = msg.sender;
        userItems[msg.sender].push(newItemId);

        pool.totalStaked += _amount;
        pool.numberOfStakers += 1;

        emit Stake(msg.sender, newItemId, _amount, reward, uint64(block.timestamp), claimDate, _stakingType);
    }

    function unstake(uint256 _amount, uint256 _itemId) external override validItem(_itemId) nonReentrant {
        UserStake storage userStake = userStakes[_itemId];
        PoolInfo storage pool = pools[userStake.stakingType - 1];
        require(_amount <= userStake.stakedAmount, "Amount exceeds staked balance");

        uint256 daysStaked = (block.timestamp - userStake.stakeTime) / 1 days;
        uint256 penalty = 0;

        // Calculate penalty if unstaking before unlock time
        if (block.timestamp < userStake.unlockTime) {
            uint256 lockDay = pool.lockDay / 1 days;  // Convert lock period to days
            penalty = (_amount * pool.penaltyFee * (lockDay - daysStaked)) / lockDay / 100;
            stakingToken.transfer(owner(), penalty); // Transfer penalty to the owner
        }

        uint256 totalWithdraw = _amount - penalty;
        userStake.stakedAmount -= _amount;

        // Recalculate reward proportionally to the remaining staked amount
        userStake.reward = (userStake.reward * userStake.stakedAmount) / (userStake.stakedAmount + _amount);

        pool.totalStaked -= _amount;

        // If all tokens are unstaked, remove the user stake record
        if (userStake.stakedAmount == 0) {
            delete userStakes[_itemId];
            delete itemOwner[_itemId];
            pool.numberOfStakers -= 1;
        }

        stakingToken.transfer(msg.sender, totalWithdraw);
        emit Unstake(msg.sender, _itemId, _amount, penalty, uint64(block.timestamp));
    }


    function claimReward(uint256 _itemId) external override validItem(_itemId) nonReentrant {
        UserStake storage userStake = userStakes[_itemId];
        PoolInfo storage pool = pools[userStake.stakingType - 1];
        require(block.timestamp >= userStake.claimDate, "Cannot claim reward before claim date");
        require(userStake.reward > 0, "No reward available");
        require(stakingToken.balanceOf(address(this)) >= userStake.reward, "Insufficient contract balance for reward");

        uint256 reward = userStake.reward;
        uint256 stakedAmount = userStake.stakedAmount; // Get the staked amount
        userStake.reward = 0; // Reset the reward after claiming
        userStake.stakedAmount = 0; // Reset the amount user staked
        if (userStake.stakedAmount == 0) {
            delete userStakes[_itemId];
            delete itemOwner[_itemId];
            pool.numberOfStakers -= 1;
        }
        // Calculate the total amount to transfer (reward + staked amount)
        uint256 totalAmountToTransfer = reward + stakedAmount;

        // Transfer the total amount (reward + staked amount)
        stakingToken.transfer(msg.sender, totalAmountToTransfer);

        emit ClaimRewardStaking(msg.sender, _itemId, reward, uint64(block.timestamp));
    }

    function getUserTotalStaked(address _user) external view override returns (uint256 totalStaked, uint256 totalReward, uint256 balance) {
        uint256[] memory items = userItems[_user];
        uint256 userTotalStaked;
        uint256 userTotalReward;

        for (uint256 i = 0; i < items.length; i++) {
            UserStake storage userStake = userStakes[items[i]];
            userTotalStaked += userStake.stakedAmount;
            userTotalReward += userStake.reward;
        }

        return (userTotalStaked, userTotalReward, stakingToken.balanceOf(_user));
    }

    function addFund(uint256 _amount) external override onlyOwner {
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        pools[0].totalReward += _amount;
    }

    function getTotalStakedPool() external view override returns (uint256 _totalStaked, uint256 _totalNumberStaker, uint256 _totalReward) {
        uint256 totalStaked = pools[0].totalStaked + pools[1].totalStaked + pools[2].totalStaked;
        uint256 totalNumberStaker = pools[0].numberOfStakers + pools[1].numberOfStakers + pools[2].numberOfStakers;
        uint256 totalReward = pools[0].totalReward + pools[1].totalReward + pools[2].totalReward;

        return (totalStaked, totalNumberStaker, totalReward);
    }


    function setLockDay(uint8 _poolIndex, uint64 _newLockDay) external onlyOwner {
        require(_poolIndex < pools.length, "Invalid pool index");
        pools[_poolIndex].lockDay = _newLockDay;
    }

    function setPenaltyFee(uint8 _poolIndex, uint256 _newPenaltyFee) external onlyOwner {
        require(_poolIndex < pools.length, "Invalid pool index");
        pools[_poolIndex].penaltyFee = _newPenaltyFee;
    }


    function getLockDay(uint8 _poolIndex) external view returns (uint64) {
        require(_poolIndex < pools.length, "Invalid pool index");
        return pools[_poolIndex].lockDay;
    }

    function getPenaltyFee(uint8 _poolIndex) external view returns (uint256) {
        require(_poolIndex < pools.length, "Invalid pool index");
        return pools[_poolIndex].penaltyFee;
    }

    function getTotalReward(uint256 _itemId) external view override returns (uint256) {
        return userStakes[_itemId].reward;
    }

    function getUserItemId(address _user) external view override returns (uint256[] memory) {
        return userItems[_user];
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function withdrawFund(uint256 _amount) external override onlyOwner {
        require(stakingToken.balanceOf(address(this)) >= _amount, "Insufficient balance");
        stakingToken.transfer(msg.sender, _amount);
    }
}
