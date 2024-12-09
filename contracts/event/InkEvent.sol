// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/signature.sol";

contract NFTContest is Ownable, SignMesssage {
    // Token and Nft contracts
    IERC20 public rewardToken;
    IERC721 public nftContract;
    // State variables
    uint256 public eventCounter;
    // Reward distribution
    uint256 public rewardForWinner;
    uint256 public rewardForVoters;

    // Event structure
    struct Event {
        uint256 id;
        string title;
        address[] participants;
        address winner;
        uint256 endTime;
        bool concluded;
        mapping(address => uint256) votes;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => address[]) public eventParticipants;
    mapping(address => uint256) public nonces;

    event EventCreated(uint256 eventId, string name, uint256 endTime);
    event NFTSubmitted(uint256 eventId, address participant, uint256 nftId);
    event Voted(uint256 eventId, address voter, address participant);
    event EventConcluded(uint256 eventId, address winner);

    constructor(
        IERC20 _inkaraCurrency,
        IERC721 _nftContract,
        uint256 _rewardForWinner,
        uint256 _rewardForVoters
    ) {
        rewardToken = _inkaraCurrency;
        nftContract = _nftContract;
        rewardForWinner = _rewardForWinner;
        rewardForVoters = _rewardForVoters;
    }

    function createEvent(
        string memory title,
        uint256 duration
    ) external onlyOwner {
        eventCounter++;
        Event storage newEvent = events[eventCounter];
        newEvent.id = eventCounter;
        newEvent.title = title;
        newEvent.endTime = block.timestamp + duration;
        emit EventCreated(eventCounter, title, newEvent.endTime);
    }

    function submitNFT(address user, uint256 eventId, uint256 nftId, uint256 nonce, bytes memory signature) external {
        require(nonce == nonces[msg.sender], "Invalid nonce");
        string memory action = "submitNft";
        
        bytes32 messageHash = getMessageHash(msg.sender, action, nonce);
        require(verifySignature(messageHash, signature), "Invalid signature");
        require(nftContract.ownerOf(nftId) == user, "You do not own this Nft");
        require(block.timestamp < events[eventId].endTime, "Event has ended");

        Event storage e = events[eventId];
        e.participants.push(user);
        nonces[msg.sender]++;

        emit NFTSubmitted(eventId, user, nftId);
    }

    function vote(uint256 eventId, address participant) external {
        require(block.timestamp < events[eventId].endTime, "Event has ended");
        require(!hasVoted(eventId, msg.sender), "You have already voted");

        Event storage e = events[eventId];
        e.votes[participant]++;
        emit Voted(eventId, msg.sender, participant);
    }

    function hasVoted(
        uint256 eventId,
        address voter
    ) public view returns (bool) {
        Event storage e = events[eventId];
        return e.votes[voter] > 0;
    }

    function concludeEvent(uint256 eventId) external onlyOwner {
        Event storage e = events[eventId];
        require(block.timestamp >= e.endTime, "Event has not ended yet");
        require(!e.concluded, "Event already concluded");

        e.concluded = true;
        address winner;
        uint256 maxVotes = 0;

        // Determine the winner
        for (uint256 i = 0; i < e.participants.length; i++) {
            address participant = e.participants[i];
            if (e.votes[participant] > maxVotes) {
                maxVotes = e.votes[participant];
                winner = participant;
            }
        }

        // Distribute rewards
        if (winner != address(0)) {
            rewardToken.transfer(winner, rewardForWinner);
            emit EventConcluded(eventId, winner);
        }

        // Distribute rewards to voters
        for (uint256 i = 0; i < e.participants.length; i++) {
            address voter = e.participants[i];
            if (hasVoted(eventId, voter)) {
                rewardToken.transfer(voter, rewardForVoters);
            }
        }
    }

    // Setters for reward amounts
    function setRewardForWinner(uint256 _rewardForWinner) external onlyOwner {
        rewardForWinner = _rewardForWinner;
    }

    function setRewardForVoters(uint256 _rewardForVoters) external onlyOwner {
        rewardForVoters = _rewardForVoters;
    }
}
