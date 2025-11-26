// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title StakingModule
 * @dev Staking contract with reward period control, separate withdrawal and claim, protected by ownership and reentrancy guard.
 */
contract StakingModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    uint256 public totalStaked;
    uint256 public rewardRatePerSecond; // reward tokens distributed per second across all stakers
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 public periodFinish;
    address public pendingOwner;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event OwnershipTransferStarted(address indexed currentOwner, address indexed pendingOwner);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardRateUpdated(uint256 rewardRatePerSecond);
    event PeriodFinishUpdated(uint256 periodFinish);
    event RewardDurationUpdated(uint256 newDuration);
    uint256 public  REWARD_DURATION = 90 days; // Initial reward duration (can be changed if needed)
    // Constructor to initialize staking and reward tokens
        constructor(
            address _stakingToken,
            address _rewardToken,
            address ownerAddress
        ) Ownable(ownerAddress) {
            require(_stakingToken != address(0) && _rewardToken != address(0), "Invalid token address");

        STAKING_TOKEN = IERC20(_stakingToken);
        REWARD_TOKEN = IERC20(_rewardToken);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }
    // Modifier to update reward for an account
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
    // Get the last time reward is applicable
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }
    // Calculate reward per token
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRatePerSecond * 1e18 / totalStaked);
    }

    // Calculate earned rewards for an account
    function earned(address account) public view returns (uint256) {
        return
            ((stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }
    // Stake tokens
    function deposit(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0 tokens");
        STAKING_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

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
        STAKING_TOKEN.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
    // Claim accumulated rewards
    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewards[msg.sender] = 0;
        REWARD_TOKEN.safeTransfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    /**
     * @notice Owner supplies a new reward amount (pulled from owner) to distribute over REWARD_DURATION.
     * Requires previous period complete, then transfers tokens in and sets new reward rate.
     */
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "Previous period must be complete");
        require(reward > 0, "Reward must be > 0");
        require(totalStaked > 0, "No stakers available"); // <-- moved/added check to prevent setting rewards when no stakers

        // Pull reward tokens from the owner (must have approved this contract)
        REWARD_TOKEN.safeTransferFrom(msg.sender, address(this), reward);

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
    // View function to get earned rewards
    function getRewards(address account) external view returns (uint256) {
        return earned(account);
    }



 function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "Zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        _transferOwnership(pendingOwner);
        pendingOwner = address(0);
    }

    function renounceOwnership() public view override onlyOwner {
        revert("Renounce disabled");
    }

    function setRewardDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0, "Duration 0");
        require(block.timestamp >= periodFinish, "Ongoing period");
        REWARD_DURATION = newDuration;
        emit RewardDurationUpdated(newDuration);
    }
}


