// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract InkReward is GovernorCountingSimple, Ownable {
    uint256 private _rewardPerProposal;
    mapping(address => mapping(uint256 => bool)) private isReward;

    constructor(uint256 defaultReward) {
        _rewardPerProposal = defaultReward;
    }

    function dropReward(uint256 proposalId) public {
        require(hasVoted(proposalId, msg.sender), "voter has not voted");
        require(
            state(proposalId) == ProposalState.Executed,
            "proposal has not executed"
        );
        require(
            isReward[msg.sender][proposalId] == false,
            "Address has been reward"
        );
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = proposalVotes(proposalId);
        uint256 totalVotes = againstVotes + forVotes + abstainVotes;
        uint256 voterPower = getVotes(msg.sender, block.number - 1);
        uint256 reward = (_rewardPerProposal * voterPower) / totalVotes;

        (bool success, ) = address(msg.sender).call{value: reward}("");
        isReward[msg.sender][proposalId] = true;
        require(success, "drop reward failed!");
    }

    function deposit() public payable {
        require(msg.value > 0, "deposit must be greater than 0");
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = address(msg.sender).call{value: balance}("");
        require(success, "withdraw failed!");
    }

    function rewardPerProposal() public view returns (uint256) {
        return _rewardPerProposal;
    }

    function setRewardPerProposal(uint256 newReward) public {
        _rewardPerProposal = newReward;
    }
}
