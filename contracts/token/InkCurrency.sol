// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract InkaraCurrency is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    Ownable,
    Pausable,
    ERC20Permit,
    ERC20Votes,
    ERC20FlashMint,
    ERC20Capped
{
    constructor()
        ERC20("Inkara", "INK")
        ERC20Permit("Inkara")
        ERC20Capped(100_000_000 * 10 ** decimals())
    {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes, ERC20Capped) {
        super._mint(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    function transferFromWithPermit(address from, address to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        require(amount > 0, "Cannot send 0");
        permit(from, msg.sender, amount, deadline, v, r, s);
        transferFrom(from, to, amount);
    }
}
