// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract InkReward is Ownable {
    uint256 public monthlyResetTime;

    mapping(address => uint256) public lastLoginDate;
    mapping(address => uint256) public consecutiveLoginDays;
    mapping(address => uint256) public allowedMintsERC4671;
    mapping(address => uint256) public allowedMintsERC721;
    mapping(address => uint256) public allowedJoinEvent;
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

    constructor() {
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

    modifier checkConsecutiveLogin() {
        uint256 currentDay = block.timestamp / 1 days;
        require(
            lastLoginDate[msg.sender] == currentDay - 1 ||
                lastLoginDate[msg.sender] == 0,
            "Login must be consecutive"
        );
        _;
    }

    function claimDailyReward() external resetMonthly checkConsecutiveLogin {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 daysSinceLastLogin = currentDay - lastLoginDate[msg.sender];

        if (daysSinceLastLogin > 1) {
            consecutiveLoginDays[msg.sender] = 1;
        } else {
            consecutiveLoginDays[msg.sender] += 1;
        }

        if (
            consecutiveLoginDays[msg.sender] == 1 && !hasClaimedDay1[msg.sender]
        ) {
            incrementMintCountERC4671(msg.sender, 1);
            hasClaimedDay1[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 1 Mint ERC4671"
            );
        } else if (
            consecutiveLoginDays[msg.sender] == 3 && !hasClaimedDay3[msg.sender]
        ) {
            incrementMintCountERC721(msg.sender, 1);
            hasClaimedDay3[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 3 Mint ERC721"
            );
        } else if (
            consecutiveLoginDays[msg.sender] == 7 && !hasClaimedDay7[msg.sender]
        ) {
            incrementJoinEvent(msg.sender, 1);
            hasClaimedDay7[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 7 Entry to Contest"
            );
        } else if (
            consecutiveLoginDays[msg.sender] == 15 &&
            !hasClaimedDay15[msg.sender]
        ) {
            incrementMintCountERC721(msg.sender, 1);
            incrementMintCountERC4671(msg.sender, 1);
            hasClaimedDay15[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 15 Mint ERC721 and ERC4671"
            );
        } else if (
            consecutiveLoginDays[msg.sender] == 30 &&
            !hasClaimedDay30[msg.sender]
        ) {
            incrementJoinEvent(msg.sender, 1);
            hasClaimedDay30[msg.sender] = true;
            emit RewardClaimed(
                msg.sender,
                block.timestamp,
                "Day 30 Entry to Contest"
            );
        }

        lastLoginDate[msg.sender] = currentDay;
    }

    function resetRewards() internal {
        hasClaimedDay1[msg.sender] = false;
        hasClaimedDay3[msg.sender] = false;
        hasClaimedDay7[msg.sender] = false;
        hasClaimedDay15[msg.sender] = false;
        hasClaimedDay30[msg.sender] = false;

        consecutiveLoginDays[msg.sender] = 0;
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
        uint256 num_of_paticipations
    ) internal {
        allowedJoinEvent[user] += num_of_paticipations;
    }

    function incrementMintCountERC4671(
        address user,
        uint256 numMints
    ) internal {
        allowedMintsERC4671[user] += numMints;
    }

    function incrementMintCountERC721(address user, uint256 numMints) internal {
        allowedMintsERC721[user] += numMints;
    }

    function decrementJoinEvent(address user) internal {
        require(allowedJoinEvent[user] > 0, "No join counts to decrement");
        allowedJoinEvent[user] -= 1;
    }

    function decrementMintCountERC4671(address user) internal {
        require(allowedMintsERC4671[user] > 0, "No mint counts to decrement");
        allowedMintsERC4671[user] -= 1;
    }

    function decrementMintCountERC721(address user) internal {
        require(allowedMintsERC721[user] > 0, "No mint counts to decrement");
        allowedMintsERC721[user] -= 1;
    }
}
