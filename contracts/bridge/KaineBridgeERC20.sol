// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20TokenWrapped.sol";

contract KaineBridgeERC20 is Ownable {
    address public bridgeAddress;
    address[] public allERC20TokenAddress;
    bytes32[] public allERC20TxHash;

    constructor(address _initialOwner) onlyValidAddress(_initialOwner) {
        transferOwnership(_initialOwner);
    }

    mapping(bytes32 => address) public erc20TokenInfoToWrappedToken;
    mapping(address => bool) public erc20TokenInfoSupported;
    mapping(bytes32 => bool) public erc20TxHashUnlocked;
    mapping(address => bytes32[]) public userERC20MintTxHash;

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Illegal address");
        _;
    }

    modifier onlyBridge() {
        require(
            msg.sender == bridgeAddress,
            "TokenWrapped::onlyBridge: Not Bridge"
        );
        _;
    }

    function addERC20TokenWrapped(
        string memory _name,
        string memory _symbol
    ) external onlyBridge returns (address) {
        bytes32 tokenInfoHash = keccak256(abi.encodePacked(_name, _symbol));
        address wrappedToken = erc20TokenInfoToWrappedToken[tokenInfoHash];
        require(wrappedToken == address(0), "The current token already exists");

        // Create a new wrapped ERC20 using create2
        ERC20TokenWrapped newWrappedToken = (new ERC20TokenWrapped){
            salt: tokenInfoHash
        }(_name, _symbol);

        // Create mappings
        address tokenWrappedAddress = address(newWrappedToken);
        erc20TokenInfoToWrappedToken[tokenInfoHash] = tokenWrappedAddress;
        erc20TokenInfoSupported[tokenWrappedAddress] = true;
        allERC20TokenAddress.push(tokenWrappedAddress);

        return tokenWrappedAddress;
    }

    function addExternalERC20Token(address tokenAddress) external onlyBridge {
        require(tokenAddress != address(0), "Invalid token address");
        require(
            !erc20TokenInfoSupported[tokenAddress],
            "Token already supported"
        );

        require(
            IERC20(tokenAddress).totalSupply() > 0,
            "Token is not a valid ERC20"
        );

        erc20TokenInfoSupported[tokenAddress] = true;
        allERC20TokenAddress.push(tokenAddress);
    }

    function mintERC20Token(
        bytes32 txHash,
        address token,
        address to,
        uint256 amount
    ) external onlyBridge {
        require(
            erc20TxHashUnlocked[txHash] == false,
            "Transaction has been executed"
        );

        erc20TxHashUnlocked[txHash] = true;
        require(erc20TokenInfoSupported[token], "This token is not supported");

        allERC20TxHash.push(txHash);
        userERC20MintTxHash[to].push(txHash);

        ERC20TokenWrapped(token).mint(to, amount);
    }

    function burnERC20Token(
        address sender,
        address token,
        uint256 amount
    ) external onlyBridge {
        require(erc20TokenInfoSupported[token], "This token is not supported");

        IERC20(token).transferFrom(sender, address(this), amount);

        (bool success, ) = token.call(
            abi.encodeWithSignature("burn(uint256)", amount)
        );

        require(success, "Burn function call failed");
    }

    function allERC20TokenAddressLength() public view returns (uint256) {
        return allERC20TokenAddress.length;
    }

    function allERC20TxHashLength() public view returns (uint256) {
        return allERC20TxHash.length;
    }

    function userERC20MintTxHashLength(
        address user
    ) public view returns (uint256) {
        return userERC20MintTxHash[user].length;
    }

    function setBlackListERC20Token(
        address token,
        address account,
        bool state
    ) external onlyBridge {
        require(erc20TokenInfoSupported[token], "This token is not supported");
        ERC20TokenWrapped(token).setBlackList(account, state);
    }

    function setBridgeAddress(address _bridgeAddress) external onlyOwner {
        bridgeAddress = _bridgeAddress;
    }
}
