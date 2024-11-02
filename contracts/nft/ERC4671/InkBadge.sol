//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/ERC4671.sol";
import "./common/ERC4671URIStorage.sol";

import "../../utils/signature.sol";

//------------------------------------------------------------
// InkaraBadge(ERC4671)
//------------------------------------------------------------
contract InkaraBadge is ERC4671URIStorage, SignMesssage {
    //--------------------------------------------------------
    // variables
    //--------------------------------------------------------
    uint256 private _tokenIdCounter;

    //--------------------------------------------------------
    // mapping
    //--------------------------------------------------------
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256) public nonces;


    // Events
    event newNftBadgeCreated(address owner, uint256 id);

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
    constructor() ERC4671("InkaraBadge", "INKB") {
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
        string calldata tokenURI, uint256 nonce, bytes memory signature
    ) external {
        require(nonce == nonces[msg.sender], "Invalid nonce");
        string memory action = "mintNft4671";
        
        bytes32 messageHash = getMessageHash(msg.sender, action, nonce);
        require(verifySignature(messageHash, signature), "Invalid signature");

        uint256 tokenId = _tokenIdCounter;

        if (_exists(tokenId)) {
            revert TokenIdAlreadyExists();
        }

        _mint(msg.sender);

        nonces[msg.sender]++;

        _setTokenURI(tokenId, tokenURI);

        emit newNftBadgeCreated(msg.sender, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal override {
        _tokenURIs[tokenId] = tokenURI;
    }
}
