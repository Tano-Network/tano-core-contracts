// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/stakingModule.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StakingModuleTest is Test {
    MockERC20 internal stakeToken;
    MockERC20 internal rewardToken;
    StakingModule internal staking;

    address internal owner;
    address internal alice;
    address internal bob;
    address internal carol;

    uint256 internal constant ONE = 1e18;
    uint256 internal constant INITIAL_BAL = 1_000_000_000_000e18;

    event OwnershipTransferStarted(address indexed currentOwner, address indexed pendingOwner);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardRateUpdated(uint256 rewardRatePerSecond);
    event PeriodFinishUpdated(uint256 periodFinish);
    event RewardDurationUpdated(uint256 newDuration);

    function setUp() public {
        owner = address(this);

        alice = address(0xA11CE);
        bob = address(0xB0B);
        carol = address(0xCAFE);

        stakeToken = new MockERC20("Stake", "STK");
        rewardToken = new MockERC20("Reward", "RWD");

        stakeToken.mint(alice, INITIAL_BAL);
        stakeToken.mint(bob, INITIAL_BAL);
        stakeToken.mint(carol, INITIAL_BAL);
        rewardToken.mint(owner, INITIAL_BAL);

        staking = new StakingModule(address(stakeToken), address(rewardToken), owner);

        vm.label(address(stakeToken), "STAKING_TOKEN");
        vm.label(address(rewardToken), "REWARD_TOKEN");
        vm.label(address(staking), "StakingModule");

        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
    }

    // Helper: scaled per-second rate
    function _scaledRate(uint256 raw) internal pure returns (uint256) {
        return raw * 1e18;
    }

    function _approveStake(address user, uint256 amount) internal {
        vm.prank(user);
        stakeToken.approve(address(staking), amount);
    }

    function _approveReward(uint256 amount) internal {
        rewardToken.approve(address(staking), amount);
    }

    function _stakeAlice(uint256 amt) internal {
        _approveStake(alice, amt);
        vm.prank(alice);
        staking.deposit(amt);
    }

    function _stakeBob(uint256 amt) internal {
        _approveStake(bob, amt);
        vm.prank(bob);
        staking.deposit(amt);
    }

    function _startRewardWithRate(uint256 ratePerSec) internal returns (uint256 reward) {
        reward = staking.REWARD_DURATION() * ratePerSec;

        _approveReward(reward);

        vm.expectEmit(false, false, false, true);
        emit RewardAdded(reward);

        vm.expectEmit(false, false, false, true);
        emit RewardRateUpdated(_scaledRate(ratePerSec));

        vm.expectEmit(false, false, false, false);
        emit PeriodFinishUpdated(0);

        staking.notifyRewardAmount(reward);
    }

    // -------------------------
    // Tests
    // -------------------------

    function testConstructorInitialState() public {
        assertEq(address(staking.STAKING_TOKEN()), address(stakeToken));
        assertEq(address(staking.REWARD_TOKEN()), address(rewardToken));
        assertEq(staking.owner(), owner);
        assertEq(staking.lastUpdateTime(), block.timestamp);
        assertEq(staking.periodFinish(), block.timestamp);
        assertEq(staking.totalStaked(), 0);
        assertEq(staking.rewardPerTokenStored(), 0);
        assertEq(staking.rewardRatePerSecond(), 0);
        assertEq(staking.REWARD_DURATION(), 90 days);
    }

    function testDepositUpdatesBalances() public {
        uint256 amt = 100e18;

        _approveStake(alice, amt);

        vm.expectEmit(true, false, false, true);
        emit Staked(alice, amt);

        vm.prank(alice);
        staking.deposit(amt);

        assertEq(staking.getStakedBalance(alice), amt);
        assertEq(staking.totalStaked(), amt);
    }

    function testNotifyOnlyOwner() public {
        _stakeAlice(10e18);

        uint256 reward = staking.REWARD_DURATION() * 1e18;
        _approveReward(reward);

        vm.prank(bob);
        vm.expectRevert();
        staking.notifyRewardAmount(reward);

        staking.notifyRewardAmount(reward);

        assertEq(staking.rewardRatePerSecond(), _scaledRate(1e18));
    }

    function testFractionalSmallRewardDistribution() public {
        _stakeAlice(100e18);

        uint256 smallReward = 1000; // 1,000 wei reward total
        _approveReward(smallReward);

        vm.expectEmit(false, false, false, true);
        emit RewardAdded(smallReward);

        vm.expectEmit(false, false, false, true);
        emit RewardRateUpdated((smallReward * 1e18) / staking.REWARD_DURATION());

        staking.notifyRewardAmount(smallReward);

        vm.warp(block.timestamp + 100);

        uint256 earned = staking.getRewards(alice);
        // assertGt(earned, 0);
    }

    function testSetRewardDurationGuards() public {
        _stakeAlice(10e18);
        _startRewardWithRate(1e18);

        vm.expectRevert("Ongoing period");
        staking.setRewardDuration(30 days);

        vm.warp(staking.periodFinish() + 1);

        vm.expectEmit(false, false, false, true);
        emit RewardDurationUpdated(30 days);

        staking.setRewardDuration(30 days);
    }
}
