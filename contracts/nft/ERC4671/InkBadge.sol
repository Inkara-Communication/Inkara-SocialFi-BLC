//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/ERC4671.sol";
import "./common/ERC4671URIStorage.sol";

import "../../reward/InkReward.sol";

//------------------------------------------------------------
// InkaraBadge(ERC4671)
//------------------------------------------------------------
contract InkaraBadge is ERC4671URIStorage, InkaraReward {
    //--------------------------------------------------------
    // variables
    //--------------------------------------------------------
    uint256 private _tokenIdCounter;

    //--------------------------------------------------------
    // mapping
    //--------------------------------------------------------
    mapping(uint256 => string) private _tokenURIs;

    // Events
    event newNftRoyalCreated(address owner, uint256 id);

    //--------------------------------------------------------
    // errors
    //--------------------------------------------------------
    error NotAllowedToMint();
    error TokenIdAlreadyExists();
    error NotTokenOwner();
    error TokenDoesNotExist();

    //--------------------------------------------------------
    // constructor
    //--------------------------------------------------------
    constructor(
        IERC20 inkaraCurrency
    ) InkaraReward(inkaraCurrency) ERC4671("InkaraBadge", "INKB") {
        _tokenIdCounter = emittedCount();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC4671) returns (bool) {
        return
            ERC4671.supportsInterface(interfaceId);
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

    function createNftRoyal(
        string calldata tokenURI
    ) external {
        uint256 tokenId = _tokenIdCounter;
        if (msg.sender != owner()) {
            if (allowedMintsERC4671[msg.sender] == 0) {
                revert NotAllowedToMint();
            }
        }

        if (_exists(tokenId)) {
            revert TokenIdAlreadyExists();
        }

        _mint(msg.sender);
        _setTokenURI(tokenId, tokenURI);

        if (msg.sender != owner()) {
            decrementMintCountERC4671(msg.sender);
        }

        emit newNftRoyalCreated(msg.sender, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal override {
        _tokenURIs[tokenId] = tokenURI;
    }
}
