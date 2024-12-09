// SPDX-License-Identifier: GPL-3.0
// Implementation of permit based on https://github.com/WETH10/WETH10/blob/main/contracts/WETH10.sol
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract ERC20TokenWrapped is ERC20Permit, ERC20Capped {
    // Target Bridge address
    address public immutable bridgeAddress;

    // Blacklist
    mapping(address => bool) public isBlackListed;

    event SetBlackList(address account, bool state);

    modifier onlyBridge() {
        require(
            msg.sender == bridgeAddress,
            "TokenWrapped::onlyBridge: Not Bridge"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol
    )
        ERC20(name, symbol)
        ERC20Permit(name)
        ERC20Capped(100_000_000 * 10 ** decimals())
    {
        bridgeAddress = msg.sender;
    }

    // Override _mint from ERC20 (ERC20Capped already enforces the cap)
    function _mint(
        address account,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount); // Call the _mint function from ERC20
    }

    function mint(address to, uint256 value) external onlyBridge {
        _mint(to, value);
    }

    // Notice that is not required to approve wrapped tokens to use the bridge
    function burn(uint256 value) external onlyBridge {
        _burn(msg.sender, value);
    }

    // Override _transfer to check for blacklist
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20) {
        require(!isBlackListed[from], "from is in blackList");
        super._transfer(from, to, value); // Call the _transfer function from ERC20
    }

    function setBlackList(address account, bool state) external onlyBridge {
        isBlackListed[account] = state;
        emit SetBlackList(account, state);
    }
}
