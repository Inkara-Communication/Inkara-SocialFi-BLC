// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Cần sửa lại sử dụng merkle airdrop
contract Airdropper {
    function multisend(
        address _tokenAddr,
        address[] memory _to,
        uint256 _value
    ) public returns (bool) {
        require(_to.length <= 150, "Too many recipients");
        for (uint8 i = 0; i < _to.length; i++) {
            require(
                ERC20(_tokenAddr).transferFrom(msg.sender, _to[i], _value),
                "Transfer failed"
            );
        }
        return true;
    }
}
