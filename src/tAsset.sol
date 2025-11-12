// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TAsset
 * @dev An ERC20 token with role-based access control for minting.
 * - The deployer is granted DEFAULT_ADMIN_ROLE.
 * - MINTER_ROLE is created to gate the minting functionality.
 * - Prevents last admin from renouncing its admin role to avoid locked state.
 */
contract TAsset is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Grant the contract deployer the default admin role.
        // This role can grant and revoke other roles.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Creates `amount` new tokens and assigns them to `to`.
     * Emits a {Transfer} event with `from` set to the zero address.
     * Requirements:
     * - The caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, msg.sender), "TAsset: caller is not a minter");
        _mint(to, amount);
    }

    function grantMinterRole(address account) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "TAsset: caller is not an admin");
        _grantRole(MINTER_ROLE, account);
    }

    /**
     * @dev Overrides renounceRole to prevent the last admin from renouncing DEFAULT_ADMIN_ROLE,
     * which would leave the contract without any admin.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        if (role == DEFAULT_ADMIN_ROLE && account == msg.sender) {
            require(getRoleMemberCount(DEFAULT_ADMIN_ROLE) > 1,
                "TAsset: cannot renounce last admin role");
        }
        super.renounceRole(role, account);
    }
}
