// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract CreatureAccessory is
    ERC1155,
    ERC2981,
    Ownable,
    Pausable,
    ERC1155Burnable
{
    mapping(uint256 => address) public creators;
    mapping(uint256 => string) customUri;
    mapping(uint256 => uint256) public tokenSupply;

    constructor(address marketplace, address auction) ERC1155("https://olive-striped-manatee-443.mypinata.cloud/ipfs/QmXcrUWCfDEC5eXwFTWGqipT51dgGJhq54DgJY3MfoQ3f9/{id}.json") {
        setApprovalForAll(marketplace, true);
        setApprovalForAll(auction, true);
    }

    modifier ownersOnly(uint256 _id) {
        require(
            balanceOf(_msgSender(), _id) > 0,
            "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED"
        );
        _;
    }

    function create(
        address _initialOwner,
        uint256 _id,
        uint256 _initialSupply,
        string memory _uri,
        bytes memory _data
    ) public onlyOwner returns (uint256) {
        require(!_exists(_id), "token _id already exists");
        creators[_id] = _msgSender();

        if (bytes(_uri).length > 0) {
            customUri[_id] = _uri;
            emit URI(_uri, _id);
        }

        _mint(_initialOwner, _id, _initialSupply, _data);

        tokenSupply[_id] = _initialSupply;
        return _id;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, ERC2981) returns (bool) {
        return
            ERC2981.supportsInterface(interfaceId) ||
            ERC1155.supportsInterface(interfaceId);
    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    function setURI(string memory _newURI) public onlyOwner {
        _setURI(_newURI);
    }

    function setCustomURI(
        uint256 _tokenId,
        string memory _newURI
    ) public ownersOnly(_tokenId) {
        customUri[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customUri[_id]);
        if (customUriBytes.length > 0) {
            return customUri[_id];
        } else {
            return super.uri(_id);
        }
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, "");
    }
}