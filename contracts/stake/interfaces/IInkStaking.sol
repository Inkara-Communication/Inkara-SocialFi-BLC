// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IInkStaking {
    // Unique Event Declarations
    event Staked(
        address indexed user,
        uint256 indexed itemId,
        uint256 amount,
        uint256 reward,
        uint64 stakeTime,
        uint64 claimDate
    );

    event Unstaked(
        address indexed user,
        uint256 indexed itemId,
        uint256 amount,
        uint256 penalty,
        uint64 unstakeTime
    );

    event RewardClaimed(
        address indexed user,
        uint256 indexed itemId,
        uint256 reward,
        uint64 claimTime
    );

    // Custom Errors
    error InvalidItemIdOrStaker();
    error AmountExceedsStakedBalance();
    error NoRewardAvailable();
    error InsufficientContractBalance();
    error InvalidStakingType();
    error AmountMustBeGreaterThanZero();
    error InsufficientContractFunds();
    error InvalidPoolIndex();

    /**
     * @notice Stake tokens in the specified pool type.
     * @param _amount The amount of tokens to stake.
     * @param _stakingType The type of staking pool (1, 2, or 3).
     */
    function stake(uint256 _amount, uint8 _stakingType) external;

    /**
     * @notice Unstake a specified amount of tokens from a specific item.
     * @param _amount The amount to unstake.
     * @param _itemId The ID of the staking item.
     */
    function unstake(uint256 _amount, uint256 _itemId) external;

    /**
     * @notice Claim rewards from a specific item.
     * @param _itemId The ID of the staking item.
     */
    function claimReward(uint256 _itemId) external;

    /**
     * @notice Get the total amount staked, total rewards, and balance of a specific user.
     * @param _user The address of the user.
     * @return totalStaked Total staked amount of the user.
     * @return totalReward Total rewards of the user.
     * @return balance Current token balance of the user.
     */
    function getUserTotalStaked(address _user)
        external
        view
        returns (uint256 totalStaked, uint256 totalReward, uint256 balance);

    /**
     * @notice Get total staked amount, number of stakers, and total rewards across all pools.
     * @return _totalStaked Total amount staked in all pools.
     * @return _totalNumberStaker Total number of stakers across all pools.
     * @return _totalReward Total rewards across all pools.
     */
    function getTotalStakedPool()
        external
        view
        returns (uint256 _totalStaked, uint256 _totalNumberStaker, uint256 _totalReward);

    /**
     * @notice Set the lock day for a specific staking pool.
     * @param _poolIndex The index of the pool to update (0, 1, or 2).
     * @param _newLockDay The new lock day value for the pool.
     */
    function setLockDay(uint8 _poolIndex, uint64 _newLockDay) external;

    /**
     * @notice Set the penalty fee for a specific staking pool.
     * @param _poolIndex The index of the pool to update (0, 1, or 2).
     * @param _newPenaltyFee The new penalty fee for the pool.
     */
    function setPenaltyFee(uint8 _poolIndex, uint256 _newPenaltyFee) external;

    /**
     * @notice Get the APY of a specific pool.
     * @param _poolIndex The index of the pool.
     * @return The APY of the specified pool.
     */
  
    function getLockDay(uint8 _poolIndex) external view returns (uint64);

    /**
     * @notice Get the penalty fee of a specific pool.
     * @param _poolIndex The index of the pool.
     * @return The penalty fee of the specified pool.
     */
    function getPenaltyFee(uint8 _poolIndex) external view returns (uint256);

    /**
     * @notice Get the total reward for a specific staking item.
     * @param _itemId The ID of the staking item.
     * @return The total reward for the specified item.
     */
    function getTotalReward(uint256 _itemId) external view returns (uint256);

    /**
     * @notice Get the list of item IDs associated with a specific user.
     * @param _user The address of the user.
     * @return An array of item IDs owned by the user.
     */
    function getUserItemId(address _user) external view returns (uint256[] memory);

    /**
     * @notice Add funds to the contract.
     * @param _amount The amount of tokens to add.
     */
    function addFund(uint256 _amount) external;

    /**
     * @notice Withdraw a specified amount of funds from the contract.
     * @param _amount The amount to withdraw.
     */
    function withdrawFund(uint256 _amount) external;

    /**
     * @notice Pause staking, unstaking, and reward claiming in the contract.
     */
    function pause() external;

    /**
     * @notice Unpause staking, unstaking, and reward claiming in the contract.
     */
    function unpause() external;
}
