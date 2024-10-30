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

contract InkaraNFT is ERC721, ERC2981, Ownable, InkaraReward {
    //--------------------------------------------------------
    // variables
    //--------------------------------------------------------
    uint16 private _tokenIdCounter = 0;

    //--------------------------------------------------------
    // mapping
    //--------------------------------------------------------
    mapping(uint256 => string) private _tokenURIs;

    //--------------------------------------------------------
    // events
    //--------------------------------------------------------
    event newNftCreated(address user, uint256 tokenId);
    event TokenBurned(address user, uint256 tokenId);
    event TokenRoyaltySet(
        uint256 tokenId,
        address receiver,
        uint16 feeNumerator
    );
    event TokenRoyaltyReset(uint256 tokenId);

    //--------------------------------------------------------
    // errors
    //--------------------------------------------------------
    error NotAllowedToMint();
    error TokenIdAlreadyExists();
    error NotTokenOwner();
    error TokenDoesNotExist();
    error InvalidRoyaltyReceiver();
    error InvalidFeeNumerator();

    //--------------------------------------------------------
    // constructor
    //--------------------------------------------------------
    constructor(
        IERC20 inkaraCurrency
    ) InkaraReward(inkaraCurrency) ERC721("Inkara", "INK") {}

    //--------------------------------------------------------
    // modifier
    //--------------------------------------------------------
    modifier onlyMinter(uint256 tokenId) {
        if (
            msg.sender != owner() &&
            msg.sender != ownerOf(tokenId)
        ) {
            revert NotTokenOwner();
        }
        _;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC2981, ERC721) returns (bool) {
        return
            ERC2981.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }

    //=======================================================================
    // [external] for ERC2981
    //=======================================================================
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint16 feeNumerator
    ) external onlyMinter(tokenId) {
        if (receiver == address(0)) {
            revert InvalidRoyaltyReceiver();
        }
        if (feeNumerator > 10000) {
            // Assuming 10000 is the max value for 100%
            revert InvalidFeeNumerator();
        }
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyMinter(tokenId) {
        _resetTokenRoyalty(tokenId);
        emit TokenRoyaltyReset(tokenId);
    }

    //-----------------------------------------
    // [internal] _exists
    //-----------------------------------------
    function _exists(uint256 tokenId) internal view override returns (bool) {
        return (ownerOf(tokenId) != address(0));
    }

    //--------------------------------------------------------
    // [public/override] tokenURI
    //--------------------------------------------------------
    function getTokenURI(
        uint256 tokenId
    ) public view virtual returns (string memory) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }
        return _tokenURIs[tokenId];
    }

    //--------------------------------------------------------
    // [external] mint
    //--------------------------------------------------------
    function mint(string calldata tokenURI, uint16 feeNumerator) external {
        uint256 tokenId = _tokenIdCounter;

        if (msg.sender != owner()) {
            if (allowedMintsERC721[msg.sender] == 0) {
                revert NotAllowedToMint();
            }
        }

        if (_exists(tokenId)) {
            revert TokenIdAlreadyExists();
        }

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);

        if (msg.sender != owner()) {
            decrementMintCountERC721(msg.sender);
        }

        _setTokenRoyalty(tokenId, msg.sender, feeNumerator);

        _tokenIdCounter++;

        emit newNftCreated(msg.sender, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
    }

    //------------------------------------------------------------------
    // [external] burn
    //------------------------------------------------------------------
    function burn(uint256 tokenId) external {
        if (msg.sender != owner() && msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        _burn(tokenId);
        emit TokenBurned(msg.sender, tokenId);
    }
}
