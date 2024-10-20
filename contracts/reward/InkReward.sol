// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InkaraReward is Ownable {
    uint256 public monthlyResetTime;
    IERC20 public inkaraCurrency;
    uint256 public dailyRewardAmount = 1 * 10 ** 18;

    mapping(address => uint256) public lastLoginDate;
    mapping(address => uint8) public totalLoginDays;
    mapping(address => uint8) public allowedMintsERC4671;
    mapping(address => uint8) public allowedMintsERC721;
    mapping(address => uint8) public allowedJoinEvent;
    mapping(address => bool) public hasClaimedDay1;
    mapping(address => bool) public hasClaimedDay3;
    mapping(address => bool) public hasClaimedDay7;
    mapping(address => bool) public hasClaimedDay15;
    mapping(address => bool) public hasClaimedDay30;

    event RewardClaimed(
        address indexed user,
        uint256 timestamp,
        string rewardType
    );
    event RewardDecremented(address indexed user, string rewardType);

    constructor(IERC20 _inkaraCurrency) {
        inkaraCurrency = _inkaraCurrency;
        monthlyResetTime = (block.timestamp / 30 days) * 30 days;
    }

    modifier resetMonthly() {
        uint256 currentMonth = block.timestamp / 30 days;
        if (currentMonth > monthlyResetTime / 30 days) {
            monthlyResetTime = currentMonth * 30 days;
            resetRewards();
        }
        _;
    }

    function claimDailyReward() external resetMonthly {
        uint256 currentDay = block.timestamp / 1 days;
        require(
            lastLoginDate[msg.sender] != currentDay,
            "Already logged in today"
        );

        lastLoginDate[msg.sender] = currentDay;
        totalLoginDays[msg.sender] += 1;

        if (totalLoginDays[msg.sender] == 1 && !hasClaimedDay1[msg.sender]) {
            incrementMintCountERC4671(msg.sender, 1);
            hasClaimedDay1[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 1 Mint ERC4671"
            );
        }
        if (totalLoginDays[msg.sender] >= 3 && !hasClaimedDay3[msg.sender]) {
            incrementMintCountERC721(msg.sender, 1);
            hasClaimedDay3[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 3 Mint ERC721"
            );
        }
        if (totalLoginDays[msg.sender] >= 7 && !hasClaimedDay7[msg.sender]) {
            incrementJoinEvent(msg.sender, 1);
            hasClaimedDay7[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 7 Entry to Contest"
            );
        }
        if (totalLoginDays[msg.sender] >= 15 && !hasClaimedDay15[msg.sender]) {
            incrementMintCountERC721(msg.sender, 1);
            incrementMintCountERC4671(msg.sender, 1);
            hasClaimedDay15[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 15 Mint ERC721 and ERC4671"
            );
        }
        if (totalLoginDays[msg.sender] >= 30 && !hasClaimedDay30[msg.sender]) {
            incrementJoinEvent(msg.sender, 1);
            hasClaimedDay30[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 30 Entry to Contest"
            );
        }
        
        require(inkaraCurrency.transfer(msg.sender, dailyRewardAmount), "Token transfer failed");
    }

    function resetRewards() internal {
        hasClaimedDay1[msg.sender] = false;
        hasClaimedDay3[msg.sender] = false;
        hasClaimedDay7[msg.sender] = false;
        hasClaimedDay15[msg.sender] = false;
        hasClaimedDay30[msg.sender] = false;

        totalLoginDays[msg.sender] = 0;
    }

    function getAllowedJoinEvent(address user) external view returns (uint256) {
        return allowedJoinEvent[user];
    }

    function getAllowedMintsERC4671(
        address user
    ) external view returns (uint256) {
        return allowedMintsERC4671[user];
    }

    function getAllowedMintsERC721(
        address user
    ) external view returns (uint256) {
        return allowedMintsERC721[user];
    }

    function incrementJoinEvent(
        address user,
        uint8 num_of_participations
    ) internal {
        allowedJoinEvent[user] += num_of_participations;
    }

    function incrementMintCountERC4671(
        address user,
        uint8 numMints
    ) internal {
        allowedMintsERC4671[user] += numMints;
    }

    function incrementMintCountERC721(address user, uint8 numMints) internal {
        allowedMintsERC721[user] += numMints;
    }

    function decrementJoinEvent(address user) internal {
        require(allowedJoinEvent[user] > 0, "No join counts to decrement");
        allowedJoinEvent[user] -= 1;
        emit RewardDecremented(user, "Join Event");
    }

    function decrementMintCountERC4671(address user) internal {
        require(allowedMintsERC4671[user] > 0, "No mint counts to decrement");
        allowedMintsERC4671[user] -= 1;
        emit RewardDecremented(user, "Mint ERC4671");
    }

    function decrementMintCountERC721(address user) internal {
        require(allowedMintsERC721[user] > 0, "No mint counts to decrement");
        allowedMintsERC721[user] -= 1;
        emit RewardDecremented(user, "Mint ERC721");
    }

    function getTotalLoginDays(address user) external view returns (uint256) {
        return totalLoginDays[user];
    }

    function hasClaimed(
        address user,
        uint8 milestone
    ) external view returns (bool) {
        if (milestone == 1) return hasClaimedDay1[user];
        if (milestone == 3) return hasClaimedDay3[user];
        if (milestone == 7) return hasClaimedDay7[user];
        if (milestone == 15) return hasClaimedDay15[user];
        if (milestone == 30) return hasClaimedDay30[user];
        return false;
    }
}
