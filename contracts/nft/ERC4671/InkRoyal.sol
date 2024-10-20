//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/ERC4671.sol";
import "./common/ERC4671URIStorage.sol";

import "../../reward/InkReward.sol";

//------------------------------------------------------------
// InkaraRoyal(ERC4671)
//------------------------------------------------------------
contract InkaraRoyal is ERC4671URIStorage, InkaraReward {
    //--------------------------------------------------------
    // variables
    //--------------------------------------------------------
    address private newOwnerOfToken;

    // Events
    event newNftRoyalCreated(address owner, uint256 id);

    //--------------------------------------------------------
    // mapping
    //--------------------------------------------------------
    mapping(address => uint256) public OwnerToId;

    //--------------------------------------------------------
    // constructor
    //--------------------------------------------------------
    constructor(
        IERC20 inkaraCurrency,
        string memory _socialName,
        string memory _tokenName
    ) InkaraReward(inkaraCurrency) ERC4671(_socialName, _tokenName) {}

    function createNftRoyal(
        address _ownerOfNftRoyal,
        string memory _tokenURI
    ) external {
        require(
            allowedMintsERC4671[_ownerOfNftRoyal] > 0,
            "No allowed mints remaining"
        );

        _mint(_ownerOfNftRoyal);
        OwnerToId[_ownerOfNftRoyal] = emittedCount() - 1;
        newOwnerOfToken = _ownerOfNftRoyal;
        _setTokenURI(OwnerToId[_ownerOfNftRoyal], _tokenURI);
        decrementMintCountERC4671(_ownerOfNftRoyal);

        emit newNftRoyalCreated(_ownerOfNftRoyal, OwnerToId[_ownerOfNftRoyal]);
    }
}
