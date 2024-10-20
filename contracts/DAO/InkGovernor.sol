// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

import "./InkReward.sol";

contract InkGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    InkReward
{
    mapping(uint256 => address[]) public _listAdressVote;
    mapping(address => uint256[]) public _listVoteAddress;
    mapping(address => mapping(uint256 => bool)) _isVote;
    // uint256 public prositionRequire;
    uint256 public _fee;

    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("InkGovernor")
        GovernorSettings(1, 100, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
        InkReward(100 ether)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function castVote(
        uint256 proposalId,
        uint8 support
    ) public override(Governor, IGovernor) returns (uint256) {
        address voter = _msgSender();
        if (_isVote[voter][proposalId] == false) {
            _listVoteAddress[voter].push(proposalId);
            _isVote[voter][proposalId] = true;
        }
        _listAdressVote[proposalId].push(voter);
        return _castVote(proposalId, voter, support, "");
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        (bool success, ) = address(msg.sender).call{value: _fee}("");
        require(success, "tranfer failed!");
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function setVotingDelay(uint256 newVotingDelay) public override onlyOwner {
        super._setVotingDelay(newVotingDelay);
    }

    function setVotingPeriod(uint256 newVotingPeriod) public override {
        super._setVotingPeriod(newVotingPeriod);
    }

    function setProposalThreshold(
        uint256 newProposalThreshold
    ) public override onlyOwner {
        super._setProposalThreshold(newProposalThreshold);
    }

    function createProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 newVotingPeriod
    ) public returns (uint256) {
        setVotingPeriod(newVotingPeriod);
        return propose(targets, values, calldatas, description);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getListAddress(
        uint256 proposalId
    ) public view returns (address[] memory) {
        return _listAdressVote[proposalId];
    }

    function getListVote(
        address account
    ) public view returns (uint256[] memory) {
        return _listVoteAddress[account];
    }

    function setFee(uint256 fee) public onlyOwner {
        _fee = fee;
    }

    function getFee() public view returns (uint256) {
        return _fee;
    }
}
