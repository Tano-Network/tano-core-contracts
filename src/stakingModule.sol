// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title StakingModule
 * @dev Staking contract with reward period control, separate withdrawal and claim, protected by ownership and reentrancy guard.
 */
contract StakingModule is Ownable, ReentrancyGuard {
    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    uint256 public totalStaked;

    uint256 public rewardRatePerSecond; // reward tokens distributed per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 public periodFinish;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardRateUpdated(uint256 rewardRatePerSecond);
    event PeriodFinishUpdated(uint256 periodFinish);

    uint256 public constant REWARD_DURATION = 90 days; // Initial reward duration (can be changed if needed)

    constructor(
        address _stakingToken,
        address _rewardToken
    ) {
        require(_stakingToken != address(0) && _rewardToken != address(0), "Invalid token address");

        STAKING_TOKEN = IERC20(_stakingToken);
        REWARD_TOKEN = IERC20(_rewardToken);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRatePerSecond * 1e18 / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        return
            ((stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function deposit(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0 tokens");
        require(STAKING_TOKEN.transferFrom(msg.sender, address(this), amount), "Stake transfer failed");

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= amount, "Insufficient balance");

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        require(STAKING_TOKEN.transfer(msg.sender, amount), "Withdraw transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewards[msg.sender] = 0;
        require(REWARD_TOKEN.transfer(msg.sender, reward), "Reward transfer failed");

        emit RewardPaid(msg.sender, reward);
    }

    /**
     * @notice Owner can notify the contract of a new reward amount to distribute over REWARD_DURATION.
     * Sets new reward rate and updates periodFinish.
     */
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "Previous period must be complete");
        require(REWARD_TOKEN.balanceOf(address(this)) >= reward, "Insufficient reward tokens");

        rewardRatePerSecond = reward / REWARD_DURATION;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + REWARD_DURATION;

        emit RewardAdded(reward);
        emit RewardRateUpdated(rewardRatePerSecond);
        emit PeriodFinishUpdated(periodFinish);
    }

    // View functions for convenience
    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalance[account];
    }

    function getRewards(address account) external view returns (uint256) {
        return earned(account);
    }
}
