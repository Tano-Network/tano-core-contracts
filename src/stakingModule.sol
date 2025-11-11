// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
* @title StakingModule
* @dev A staking contract with rewards where users deposit ERC20 tokens and earn proportional rewards.
*/
contract StakingModule is Ownable, ReentrancyGuard {
    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    uint256 public totalStaked;
    uint256 public rewardRatePerSecond; // reward tokens distributed per second across all stakers
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public maxRewardDuration; // maximum duration over which rewards are distributed (in seconds)

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRewardRate);
    event MaxRewardDurationUpdated(uint256 newDuration);

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _totalAllocatedRewards,
        uint256 _initialRewardDuration
    ) {
        require(_stakingToken != address(0) && _rewardToken != address(0), "Invalid token address");
        require(_initialRewardDuration > 0, "Reward duration must be greater than zero");

        STAKING_TOKEN = IERC20(_stakingToken);
        REWARD_TOKEN = IERC20(_rewardToken);

        maxRewardDuration = _initialRewardDuration;
        rewardRatePerSecond = _totalAllocatedRewards / maxRewardDuration;

        lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // Calculate accumulated rewards per token staked
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRatePerSecond * 1e18 / totalStaked);
    }

    // Calculate the earned rewards for a user
    function earned(address account) public view returns (uint256) {
        return
            (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) +
            rewards[account];
    }

    // Stake tokens
    function deposit(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0 tokens");
        require(STAKING_TOKEN.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    // Withdraw staked tokens
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= amount, "Insufficient balance");

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        require(STAKING_TOKEN.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    // Claim accumulated rewards
    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewards[msg.sender] = 0;
        require(REWARD_TOKEN.transfer(msg.sender, reward), "Reward transfer failed");
        emit RewardPaid(msg.sender, reward);
    }

    // Update the reward rate with validation against reward token balance
    function setRewardRate(uint256 newRewardRate) external onlyOwner updateReward(address(0)) {
        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));

        // Ensure contract has enough reward tokens to cover emissions for maxRewardDuration
        uint256 requiredRewards = newRewardRate * maxRewardDuration;
        require(rewardBalance >= requiredRewards, "Insufficient reward token balance for new rate");

        rewardRatePerSecond = newRewardRate;
        emit RewardRateUpdated(newRewardRate);
    }

    // Update the max reward distribution duration and recalculate reward rate
    function setMaxRewardDuration(uint256 newDuration) external onlyOwner updateReward(address(0)) {
        require(newDuration > 0, "Reward duration must be greater than zero");
        maxRewardDuration = newDuration;

        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));
        uint256 newRewardRate = rewardBalance / maxRewardDuration;

        rewardRatePerSecond = newRewardRate;

        emit RewardRateUpdated(newRewardRate);
        emit MaxRewardDurationUpdated(newDuration);
    }

    // View function to get staked balance for a user
    function getStakedBalance(address user) external view returns (uint256) {
        return stakedBalance[user];
    }

    // View function to get rewards accumulated (not yet claimed) for a user
    function getRewards(address user) external view returns (uint256) {
        return earned(user);
    }
}
