// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract Creature is ERC721, ERC2981, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC2981, ERC721) returns (bool) {
        return
            ERC2981.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }

    constructor(address marketplace, address auction) ERC721("Mezas Creatue", "MC") {
        setApprovalForAll(marketplace, true);
        setApprovalForAll(auction, true);
    }

    function safeMint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId, "");
    }
}
