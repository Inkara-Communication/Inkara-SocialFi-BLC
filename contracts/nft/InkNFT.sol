// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../reward/InkReward.sol";
//------------------------------------------------------------
// InkaraNFT(ERC721)
//------------------------------------------------------------
contract InkaraNFT is ERC721, ERC2981, Ownable, InkReward {
    //--------------------------------------------------------
    // variables
    //--------------------------------------------------------
    string private baseURI;
    string public baseExtension = ".json";

    //--------------------------------------------------------
    // event
    //--------------------------------------------------------
    event newNftCreated(address user, uint256 tokenId);
    
    //--------------------------------------------------------
    // constructor
    //--------------------------------------------------------
    constructor(address marketplace, address auction) ERC721("Inkara", "INK") {
        setApprovalForAll(marketplace, true);
        setApprovalForAll(auction, true);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC2981, ERC721) returns (bool) {
        return
            ERC2981.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }

    //=======================================================================
    // [external/onlyOwner] for ERC2981
    //=======================================================================
    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    //--------------------------------------------------------
    // [external/onlyOwner] setBaseUri
    //--------------------------------------------------------
    function setBaseUri(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    //-----------------------------------------
    // [internal] _exists
    //-----------------------------------------
    function _exists(uint256 tokenId) internal view override returns (bool) {
        return (ownerOf(tokenId) != address(0));
    }

    //-----------------------------------------
    // [internal] _baseURI
    //-----------------------------------------
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    //--------------------------------------------------------
    // [public/override] tokenURI
    //--------------------------------------------------------
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        Strings.toString(tokenId),
                        baseExtension
                    )
                )
                : "";
    }

    //--------------------------------------------------------
    // [external] mint
    //--------------------------------------------------------
    function mint(address user, uint256 tokenId) external {
        require(allowedMintsERC721[user] > 0, "No allowed mints remaining");

        _mint(user, tokenId);
        decrementMintCountERC721(user);

        emit newNftCreated(user, tokenId);
    }

    //------------------------------------------------------------------
    // [external] burn
    //------------------------------------------------------------------
    function burn(uint256 tokenId) external {
        require(
            msg.sender == owner() || msg.sender == ownerOf(tokenId),
            "burn: caller is not the owner"
        );

        _burn(tokenId);
    }
}
