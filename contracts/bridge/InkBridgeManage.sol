// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IInkBridgeERC20.sol";
import "./BridgeFeeRates.sol";

contract InkaraBridgeManage is Ownable {
    bytes32[] public allNativeTokenTxHash;

    address public bridgeERC20Address;

    uint256 public bridgeFee;
    address public feeAddress;

    uint256 public constant MaxBridgeFee = 5 * 10 ** 16; //max 0.05

    bool public paused;

    using BridgeFeeRates for BridgeFeeRates.White;
    BridgeFeeRates.White private white;

    mapping(bytes32 => bool) public nativeTokenTxHashUnlocked;
    mapping(address => bytes32[]) public userNativeTokenMintTxHash;

    event SetWhiteList(address owner, address addressKey, uint256 rate);

    event DeleteWhiteList(address owner, address addressKey);

    event PauseEvent(address owner, bool paused);

    event AddERC20TokenWrapped(
        address tokenWrappedAddress,
        string name,
        string symbol
    );

    event AddExternalERC20Token(address tokenAddress);

    event MintERC20Token(
        bytes32 txHash,
        address token,
        address account,
        uint256 amount
    );

    event BurnERC20Token(
        address token,
        address account,
        uint256 amount,
        uint256 bridgeFee
    );

    event SetBlackListERC20Token(
        address owner,
        address token,
        address account,
        bool state
    );

    event UnlockNativeToken(bytes32 txHash, address account, uint256 amount);

    event LockNativeToken(address account, uint256 amount);

    event LockNativeTokenWithBridgeFee(
        address account,
        uint256 amount,
        uint256 bridgeFee
    );

    event SetBridgeSettingsFee(
        address feeAddress,
        uint256 bridgeFee,
        address feeAddressOld,
        uint256 bridgeFeeOld
    );

    error EtherTransferFailed();

    receive() external payable {}

    constructor(
        address _initialOwner,
        address _bridgeERC20Address,
        address _feeAddress
    ) {
        bridgeERC20Address = _bridgeERC20Address;
        feeAddress = _feeAddress;
        transferOwnership(_initialOwner);
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Illegal address");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "pause is on");
        _;
    }

    function addERC20TokenWrapped(
        string memory _name,
        string memory _symbol
    ) external onlyOwner returns (address) {
        address tokenWrappedAddress = IInkBridgeERC20(bridgeERC20Address)
            .addERC20TokenWrapped(_name, _symbol);
        emit AddERC20TokenWrapped(tokenWrappedAddress, _name, _symbol);
        return tokenWrappedAddress;
    }

    function addExternalERC20Token(
        address token
    ) external onlyOwner whenNotPaused {
        IInkBridgeERC20(bridgeERC20Address).addExternalERC20Token(token);
        emit AddExternalERC20Token(token);
    }

    function mintERC20Token(
        bytes32 txHash,
        address token,
        address to,
        uint256 amount
    ) external onlyOwner whenNotPaused {
        IInkBridgeERC20(bridgeERC20Address).mintERC20Token(
            txHash,
            token,
            to,
            amount
        );
        emit MintERC20Token(txHash, token, to, amount);
    }

    function burnERC20Token(
        address token,
        uint256 amount
    ) public payable whenNotPaused {
        require(amount > 0, "Invalid amount");

        uint256 _bridgeFee = getBridgeFee(msg.sender, token);
        require(msg.value == _bridgeFee, "Invalid bridgeFee");

        if (_bridgeFee > 0) {
            (bool success, ) = feeAddress.call{value: _bridgeFee}(new bytes(0));
            if (!success) {
                revert EtherTransferFailed();
            }
        }
        IInkBridgeERC20(bridgeERC20Address).burnERC20Token(
            msg.sender,
            token,
            amount
        );
        emit BurnERC20Token(token, msg.sender, amount, _bridgeFee);
    }

    function setBlackListERC20Token(
        address token,
        address account,
        bool state
    ) external onlyOwner {
        IInkBridgeERC20(bridgeERC20Address).setBlackListERC20Token(
            token,
            account,
            state
        );
        emit SetBlackListERC20Token(msg.sender, token, account, state);
    }

    function unlockNativeToken(
        bytes32 txHash,
        address addressTo,
        uint256 amount
    ) external onlyOwner whenNotPaused onlyValidAddress(addressTo) {
        require(
            !nativeTokenTxHashUnlocked[txHash],
            "Transaction has been executed"
        );

        nativeTokenTxHashUnlocked[txHash] = true;
        allNativeTokenTxHash.push(txHash);
        userNativeTokenMintTxHash[addressTo].push(txHash);

        (bool success, ) = addressTo.call{value: amount}(new bytes(0));
        if (!success) {
            revert EtherTransferFailed();
        }
        emit UnlockNativeToken(txHash, addressTo, amount);
    }

    function lockNativeToken() public payable whenNotPaused {
        uint256 _bridgeFee = getBridgeFee(msg.sender, address(0));
        require(msg.value > _bridgeFee, "Insufficient cross-chain assets");

        if (_bridgeFee > 0) {
            (bool success, ) = feeAddress.call{value: _bridgeFee}(new bytes(0));
            if (!success) {
                revert EtherTransferFailed();
            }
        }

        emit LockNativeTokenWithBridgeFee(
            msg.sender,
            msg.value - _bridgeFee,
            _bridgeFee
        );
    }

    function allERC20TokenAddressLength() public view returns (uint256) {
        return
            IInkBridgeERC20(bridgeERC20Address).allERC20TokenAddressLength();
    }

    function allERC20TxHashLength() public view returns (uint256) {
        return IInkBridgeERC20(bridgeERC20Address).allERC20TxHashLength();
    }

    function allNativeTokenTxHashLength() public view returns (uint256) {
        return allNativeTokenTxHash.length;
    }

    function userERC20MintTxHashLength(
        address user
    ) public view returns (uint256) {
        return
            IInkBridgeERC20(bridgeERC20Address).userERC20MintTxHashLength(
                user
            );
    }

    function userNativeTokenMintTxHashLength(
        address user
    ) public view returns (uint256) {
        return userNativeTokenMintTxHash[user].length;
    }

    function setBridgeSettingsFee(
        address _feeAddress,
        uint256 _bridgeFee
    ) external onlyOwner {
        require(_bridgeFee <= MaxBridgeFee, "bridgeFee is too high"); //max 0.05

        address feeAddressOld = feeAddress;
        uint256 bridgeFeeOld = bridgeFee;

        if (_feeAddress != address(0)) {
            feeAddress = _feeAddress;
        }
        if (_bridgeFee > 0) {
            bridgeFee = _bridgeFee;
        }

        emit SetBridgeSettingsFee(
            _feeAddress,
            _bridgeFee,
            feeAddressOld,
            bridgeFeeOld
        );
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit PauseEvent(msg.sender, paused);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit PauseEvent(msg.sender, paused);
    }

    //_address is msg.sender or token.
    function setWhiteList(address _address, uint256 _rate) external onlyOwner {
        white.setWhiteList(_address, _rate);
        emit SetWhiteList(msg.sender, _address, _rate);
    }

    function deleteWhiteList(address _address) external onlyOwner {
        white.deleteWhiteList(_address);
        emit DeleteWhiteList(msg.sender, _address);
    }

    function getBridgeFee(
        address msgSender,
        address token
    ) public view returns (uint256) {
        return (bridgeFee * white.getBridgeFeeRate(msgSender, token)) / 100;
    }

    function getBridgeFeeTimes(
        address msgSender,
        address token,
        uint256 times
    ) public view returns (uint256) {
        return
            (bridgeFee * white.getBridgeFeeRateTimes(msgSender, token, times)) /
            100;
    }
}
