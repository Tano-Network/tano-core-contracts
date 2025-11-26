// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title StakingModule
 * @dev Staking contract with: fractional reward-rate, updateReward logic,
 *      separate withdraw / claim, two-step ownership, nonReentrant guards.
 *
 * NOTE: rewardRatePerSecond is stored in 1e18 fixed point:
 *       rewardRatePerSecond = (reward * 1e18) / REWARD_DURATION;
 */
contract StakingModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    uint256 public totalStaked;

    /// @notice Stored in 1e18 precision to allow fractional-per-second rates
    uint256 public rewardRatePerSecond;

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
    event RewardRateUpdated(uint256 rewardRatePerSecondScaled);
    event PeriodFinishUpdated(uint256 periodFinish);
    event RewardDurationUpdated(uint256 newDuration);

    uint256 public REWARD_DURATION = 90 days;

    constructor(address _stakingToken, address _rewardToken, address ownerAddress) Ownable(ownerAddress) {
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
            rewards[account] =
                ((stakedBalance[account] * (rewardPerTokenStored - userRewardPerTokenPaid[account])) / 1e18)
                + rewards[account];

            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;

        uint256 dt = lastTimeRewardApplicable() - lastUpdateTime;

        return rewardPerTokenStored + (dt * rewardRatePerSecond) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return ((stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18)
            + rewards[account];
    }

    // -------------------------
    // Staking logic
    // -------------------------

    function deposit(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0 tokens");
        STAKING_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= amount, "Insufficient balance");

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        STAKING_TOKEN.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewards[msg.sender] = 0;
        REWARD_TOKEN.safeTransfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    // -------------------------
    // Reward logic
    // -------------------------

    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "Previous period must be complete");
        require(reward > 0, "Reward must be > 0");
        require(totalStaked > 0, "No stakers available");

        REWARD_TOKEN.safeTransferFrom(msg.sender, address(this), reward);

        rewardRatePerSecond = (reward * 1e18) / REWARD_DURATION;

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + REWARD_DURATION;

        emit RewardAdded(reward);
        emit RewardRateUpdated(rewardRatePerSecond);
        emit PeriodFinishUpdated(periodFinish);
    }

    // -------------------------
    // Ownership (two-step)
    // -------------------------

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

    function renounceOwnership() public override onlyOwner {
        revert("Renounce disabled");
    }

    // -------------------------
    // Admin
    // -------------------------

    function setRewardDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0, "StakingDuration 0");
        require(block.timestamp >= periodFinish, "Ongoing period");

        REWARD_DURATION = newDuration;
        emit RewardDurationUpdated(newDuration);
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalance[account];
    }

    function getRewards(address account) external view returns (uint256) {
        return rewards[account];
    }
}
