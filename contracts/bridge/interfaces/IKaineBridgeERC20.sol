// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IKaineBridgeERC20 {
    function addERC20TokenWrapped(
        string memory _name,
        string memory _symbol
    ) external returns (address);
    function addExternalERC20Token(address token) external;
    function mintERC20Token(
        bytes32 txHash,
        address token,
        address to,
        uint256 amount
    ) external;
    function burnERC20Token(
        address sender,
        address token,
        uint256 amount
    ) external;
    function allERC20TokenAddressLength() external view returns (uint256);
    function allERC20TxHashLength() external view returns (uint256);
    function userERC20MintTxHashLength(
        address user
    ) external view returns (uint256);
    function setBlackListERC20Token(
        address token,
        address account,
        bool state
    ) external;
}
