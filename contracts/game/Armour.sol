// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Armor is ERC721 {
    address minter;
    address private owner;

    event MinterChanged(address indexed from, address to);

    constructor() payable ERC721("Armour", "ARM") {
    }

    function passMinterRole(address farm) public returns (bool) {
        require(msg.sender == minter, "You are not minter");
        minter = farm;

        emit MinterChanged(msg.sender, farm);
        return true;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function mint(address account, uint256 tokenId) public {
        require(msg.sender == minter, "You are not the minter");

        _safeMint(account, tokenId, "");
    }

    function burn(address account, uint256 amount) public {
        require(msg.sender == minter, "You are not the minter");
        _burn(amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 tokenId
    ) public virtual override {
        require(msg.sender == minter, "You are not the minter");

        _transfer(sender, recipient, tokenId);
    }
}
