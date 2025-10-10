// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title StakingModule
 * @dev A simple staking contract where users can deposit and withdraw ERC20 tokens.
 */
contract StakingModule {

    // --- State Variables ---

    // The ERC20 token that will be staked
    IERC20 public immutable STAKING_TOKEN;

    // Total amount of tokens staked in the contract
    uint256 public totalStaked;

    // Mapping from user address to their staked balance
    mapping(address => uint256) public stakedBalance;

    // --- Events ---

    /**
     * @dev Emitted when a user deposits tokens.
     * @param user The address of the user who deposited.
     * @param amount The amount of tokens deposited.
     */
    event Staked(address indexed user, uint256 amount);

    /**
     * @dev Emitted when a user withdraws tokens.
     * @param user The address of the user who withdrew.
     * @param amount The amount of tokens withdrawn.
     */
    event Withdrawn(address indexed user, uint256 amount);

    // --- Constructor ---

    /**
     * @dev Sets the staking token address upon deployment.
     * @param _stakingToken The address of the ERC20 token to be used for staking.
     */
    constructor(address _stakingToken) {
        require(_stakingToken != address(0), "StakingModule: Staking token cannot be the zero address");
        STAKING_TOKEN = IERC20(_stakingToken);
    }

    // --- Staking Functions ---

    /**
     * @dev Allows a user to deposit tokens into the staking contract.
     * The user must first approve the contract to spend the tokens.
     * @param _amount The amount of tokens to stake.
     */
    function deposit(uint256 _amount) external {
        require(_amount > 0, "StakingModule: Cannot stake 0 tokens");

        // The contract needs to be approved to transfer tokens on behalf of the user
        // This transfer will fail if the user has not approved enough tokens
        bool success = STAKING_TOKEN.transferFrom(msg.sender, address(this), _amount);
        require(success, "StakingModule: Token transfer failed. Check allowance.");

        // Update user's staked balance and total staked amount
        stakedBalance[msg.sender] = stakedBalance[msg.sender]+ _amount;
        totalStaked = totalStaked+_amount;

        emit Staked(msg.sender, _amount);
    }

    /**
     * @dev Allows a user to withdraw their staked tokens.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "StakingModule: Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= _amount, "StakingModule: Insufficient staked balance");

        // Update user's staked balance and total staked amount first to prevent re-entrancy attacks
        stakedBalance[msg.sender] = stakedBalance[msg.sender] - _amount;
        totalStaked = totalStaked-_amount;
    
        // Transfer the tokens back to the user
        bool success = STAKING_TOKEN.transfer(msg.sender, _amount);
        require(success, "StakingModule: Token transfer failed.");

        emit Withdrawn(msg.sender, _amount);
    }

    // --- View Functions ---

    /**
     * @dev Returns the staked balance of a specific user.
     * @param _user The address of the user.
     * @return The amount of tokens staked by the user.
     */
    function getStakedBalance(address _user) external view returns (uint256) {
        return stakedBalance[_user];
    }
}
