// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * CampusCreditV2
 * - Cap enforced on mint
 * - Pausable transfers
 * - Roles: ADMIN, MINTER, PAUSER
 * - Batch airdrop (gas-aware), custom errors
 */
contract CampusCreditV2 is ERC20, ERC20Burnable, ERC20Capped, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    error CapExceeded();
    error ArrayLengthMismatch();

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,                 // in wei (18 decimals)
        address initialReceiver,
        uint256 initialMint           // in wei
    )
        ERC20(name_, symbol_)
        ERC20Capped(cap_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        if (initialMint > 0) {
            _mint(initialReceiver, initialMint);
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function airdrop(address[] calldata to, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        if (to.length != amounts.length) revert ArrayLengthMismatch();

        uint256 len = to.length;
        uint256 sum;
        for (uint256 i = 0; i < len; ) {
            sum += amounts[i];
            unchecked { ++i; }
        }
        if (totalSupply() + sum > cap()) revert CapExceeded();

        for (uint256 j = 0; j < len; ) {
            _mint(to[j], amounts[j]);
            unchecked { ++j; }
        }
    }

    // combine hooks
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Capped)
    {
        super._update(from, to, value);
    }
}
