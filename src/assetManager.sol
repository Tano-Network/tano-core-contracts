// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IMyToken
 * @dev Interface for our ERC20 token contract.
 * Using an interface is a best practice for contract interaction.
 */
interface IMyToken {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}

/**
 * @title AssetManager
 * @dev Manages user whitelists and orchestrates minting/burning of a specific ERC20 token.
 */
contract AssetManager is Ownable {
    // --- State Variables ---

    IMyToken public immutable token;

    struct WhitelistedUser {
        uint256 mintAllowance; // Total tokens the user is allowed to mint.
        uint256 mintedAmount;  // Total tokens the user has already minted.
    }

    mapping(address => WhitelistedUser) public whitelist;

    // --- Events ---

    event UserWhitelisted(address indexed user, uint256 allowance);
    event TokensMinted(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);

    // --- Constructor ---

    /**
     * @dev Sets the token address and transfers ownership.
     * @param _tokenAddress The address of the MyToken contract.
     * @param initialOwner The address that will own this AssetManager.
     */
    constructor(address _tokenAddress, address initialOwner) Ownable(initialOwner) {
        require(_tokenAddress != address(0), "AssetManager: Invalid token address");
        token = IMyToken(_tokenAddress);
    }

    // --- Whitelist Management ---

    /**
     * @dev Adds or updates a user's minting allowance. Only callable by the owner.
     * @param user The address of the user to whitelist.
     * @param allowance The total number of tokens the user is permitted to mint.
     */
    function setWhitelist(address user, uint256 allowance) external onlyOwner {
        require(user != address(0), "AssetManager: Cannot whitelist the zero address");
        
        // Note: This will reset the minted amount for an existing user.
        // If you want to only update allowance, you'd do:
        // whitelist[user].mintAllowance = allowance;
        whitelist[user] = WhitelistedUser({
            mintAllowance: allowance,
            mintedAmount: 0 
        });

        emit UserWhitelisted(user, allowance);
    }

    // --- Core Functions ---

    /**
     * @dev Allows a whitelisted user to mint tokens up to their allowance.
     * The AssetManager contract must have the MINTER_ROLE on the token contract.
     */
    function mint(uint256 amount) external {
        WhitelistedUser storage user = whitelist[msg.sender];
        
        // Checks
        require(user.mintAllowance > 0, "AssetManager: You are not whitelisted");
        require(amount > 0, "AssetManager: Amount must be greater than zero");
        require(user.mintedAmount + amount <= user.mintAllowance, "AssetManager: Mint amount exceeds allowance");

        // Effects
        user.mintedAmount += amount;

        // Interaction
        token.mint(msg.sender, amount);

        emit TokensMinted(msg.sender, amount);
    }

    /**
     * @dev Burns a specified amount of tokens from the caller's balance.
     * The user must first approve the AssetManager contract to spend their tokens.
     */
    function burn(uint256 amount) external {
        require(amount > 0, "AssetManager: Amount must be greater than zero");
        
        // This will call the burnFrom function on the token contract.
        // The user (msg.sender) must have approved this contract address.
        token.burnFrom(msg.sender, amount);

        emit TokensBurned(msg.sender, amount);
    }

    // --- View Functions ---
    function getAllowance(address user) external view returns (uint256) {
        return whitelist[user].mintAllowance;
    }

    function getMintedAmount(address user) external view returns (uint256) {
        return whitelist[user].mintedAmount;
    }

    function getMintableAmount(address user) external view returns (uint256) {
        WhitelistedUser storage whitelistedUser = whitelist[user];
        return whitelistedUser.mintAllowance - whitelistedUser.mintedAmount;
    }
    
    function isWhitelisted(address user) external view returns (bool) {
        return whitelist[user].mintAllowance > 0;
    }
}