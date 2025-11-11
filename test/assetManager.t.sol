// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AssetManager} from "../src/assetManager.sol";
import {TAsset} from "../src/tAsset.sol";

contract AssetManagerTest is Test {
    AssetManager public manager;
    TAsset public token;
    address public admin;
    address public user1;
    address public user2;
    address public verifier;
    
    event UserWhitelisted(address indexed user, uint256 allowance);
    event TokensMinted(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);
    
    function setUp() public {
        admin = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        verifier = makeAddr("verifier");
        
        token = new TAsset("Tano Asset", "TASSET");
        manager = new AssetManager(address(token), admin, verifier, bytes32(0), 18);
        
        // Grant minter role to the manager
        token.grantMinterRole(address(manager));
        
        // Label addresses for better trace output
        vm.label(admin, "Admin");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(address(token), "Token");
        vm.label(address(manager), "Manager");
        vm.label(verifier, "Verifier");
    }
    
    // Test initial state
    function testInitialState() public view {
        assertEq(address(manager.TOKEN()), address(token));
        assertEq(manager.owner(), admin);
        assertFalse(manager.isWhitelisted(user1));
        assertFalse(manager.isWhitelisted(user2));
    }
    
    // Test whitelist management
    function testWhitelistUser() public {
        uint256 allowance = 1000 * 10**18;
        
        vm.expectEmit(true, false, false, true);
        emit UserWhitelisted(user1, allowance);
        
        manager.setWhitelist(user1, allowance);
        
        assertTrue(manager.isWhitelisted(user1));
        assertEq(manager.getAllowance(user1), allowance);
        assertEq(manager.getMintedAmount(user1), 0);
        assertEq(manager.getMintableAmount(user1), allowance);
    }
    
    // Test updating whitelist
    function testUpdateWhitelist() public {
        uint256 initialAllowance = 1000 * 10**18;
        manager.setWhitelist(user1, initialAllowance);
        
        // Mint some tokens
        vm.prank(user1);
        manager.mint(500 * 10**18);
        
        // Update allowance
        uint256 newAllowance = 2000 * 10**18;
        vm.expectRevert("AssetManager: User already whitelisted");
        manager.setWhitelist(user1, newAllowance);
        
        // Check that minted amount was reset
        assertEq(manager.getMintedAmount(user1), 500 * 10**18);
        assertEq(manager.getMintableAmount(user1),initialAllowance - 500 * 10**18);
    }
    
    // Test non-owner cannot whitelist
    function test_RevertWhen_NonOwnerWhitelists() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        manager.setWhitelist(user2, 1000 * 10**18);
    }
    
    // Test cannot whitelist zero address
    function test_RevertWhen_WhitelistingZeroAddress() public {
        vm.expectRevert("AssetManager: Cannot whitelist the zero address");
        manager.setWhitelist(address(0), 1000 * 10**18);
    }
    
    // Test minting
    function testMint() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        uint256 mintAmount = 500 * 10**18;
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit TokensMinted(user1, mintAmount);
        
        manager.mint(mintAmount);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(manager.getMintedAmount(user1), mintAmount);
        assertEq(manager.getMintableAmount(user1), allowance - mintAmount);
    }

    function testMint_When_Paused() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        uint256 mintAmount = 500 * 10**18;
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit TokensMinted(user1, mintAmount);
        
        manager.mint(mintAmount);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(manager.getMintedAmount(user1), mintAmount);
        assertEq(manager.getMintableAmount(user1), allowance - mintAmount);

        vm.prank(admin);
        // Pause the contract
        manager.pause();

        vm.prank(user1);
        vm.expectRevert("EnforcedPause()");
        manager.mint(100 * 10**18);
        
        // Recheck previous state
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(manager.getMintedAmount(user1), mintAmount);
        assertEq(manager.getMintableAmount(user1), allowance - mintAmount);
    }

    
    // Test minting multiple times
    function testMultipleMints() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        // First mint
        vm.prank(user1);
        manager.mint(300 * 10**18);
        
        // Second mint
        vm.prank(user1);
        manager.mint(400 * 10**18);
        
        assertEq(token.balanceOf(user1), 700 * 10**18);
        assertEq(manager.getMintedAmount(user1), 700 * 10**18);
        assertEq(manager.getMintableAmount(user1), 300 * 10**18);
    }
    
    // Test minting fails for non-whitelisted user
    function test_RevertWhen_NonWhitelistedUserMints() public {
        vm.prank(user1);
        vm.expectRevert("AssetManager: You are not whitelisted");
        manager.mint(100 * 10**18);
    }
    
    // Test minting zero amount fails
    function test_RevertWhen_MintingZeroAmount() public {
        manager.setWhitelist(user1, 1000 * 10**18);
        
        vm.prank(user1);
        vm.expectRevert("AssetManager: Amount must be greater than zero");
        manager.mint(0);
    }
    
    // Test minting more than allowance fails
    function test_RevertWhen_MintingMoreThanAllowance() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        vm.prank(user1);
        vm.expectRevert("AssetManager: Mint amount exceeds allowance");
        manager.mint(1001 * 10**18);
    }
    
    // Test burning
    function testBurn() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        // Mint tokens
        vm.prank(user1);
        manager.mint(500 * 10**18);
        
        // Burn tokens
        uint256 burnAmount = 200 * 10**18;
        vm.startPrank(user1);
        token.approve(address(manager), burnAmount);
        
        vm.expectEmit(true, false, false, true);
        emit TokensBurned(user1, burnAmount);
        
        manager.burn(burnAmount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), 300 * 10**18);
    }
    
    // Test burning zero amount fails
    function test_RevertWhen_BurningZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("AssetManager: Amount must be greater than zero");
        manager.burn(0);
    }
    
    // Test burning without approval fails
    function test_RevertWhen_BurningWithoutApproval() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        // Mint tokens
        vm.prank(user1);
        manager.mint(500 * 10**18);
        
        // Try to burn without approval
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientAllowance(address,uint256,uint256)", address(manager), 0, 200 * 10**18));
        manager.burn(200 * 10**18);
    }
    
    // Test view functions
    function testViewFunctions() public {
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user1, allowance);
        
        // Mint some tokens
        vm.prank(user1);
        manager.mint(300 * 10**18);
        
        // Check view functions
        assertEq(manager.getAllowance(user1), allowance);
        assertEq(manager.getMintedAmount(user1), 300 * 10**18);
        assertEq(manager.getMintableAmount(user1), 700 * 10**18);
        assertTrue(manager.isWhitelisted(user1));
        
        // Check for non-whitelisted user
        assertEq(manager.getAllowance(user2), 0);
        assertEq(manager.getMintedAmount(user2), 0);
        assertEq(manager.getMintableAmount(user2), 0);
        assertFalse(manager.isWhitelisted(user2));
    }
    
    // Test multiple users with different allowances
    function testMultipleUsers() public {
        // Set different allowances for different users
        manager.setWhitelist(user1, 1000 * 10**18);
        manager.setWhitelist(user2, 2000 * 10**18);
        
        // User 1 mints
        vm.prank(user1);
        manager.mint(500 * 10**18);
        
        // User 2 mints
        vm.prank(user2);
        manager.mint(1500 * 10**18);
        
        // Check balances and allowances
        assertEq(token.balanceOf(user1), 500 * 10**18);
        assertEq(token.balanceOf(user2), 1500 * 10**18);
        
        assertEq(manager.getMintedAmount(user1), 500 * 10**18);
        assertEq(manager.getMintedAmount(user2), 1500 * 10**18);
        
        assertEq(manager.getMintableAmount(user1), 500 * 10**18);
        assertEq(manager.getMintableAmount(user2), 500 * 10**18);
    }
    
    // Test ownership transfer
    function testOwnershipTransfer() public {
        // Transfer ownership
        manager.transferOwnership(user1);
        
        // Check new owner
        assertEq(manager.owner(), user1);
        
        // New owner can whitelist
        vm.prank(user1);
        manager.setWhitelist(user2, 1000 * 10**18);
        
        // Old owner cannot whitelist
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        manager.setWhitelist(user1, 1000 * 10**18);
    }

    // Test ZK minted amount
    function testInitialZkMintedAmount() public view {
        assertEq(manager.getZkMintedAmount(user1), 0);
    }

    // Test changing program VKey
    function testChangeProgramVKey() public {
        bytes32 newVKey = keccak256("newVKey");
        manager.changeProgramVKey(newVKey);
        assertEq(manager.programVKey(), newVKey);
    }

    function test_RevertWhen_NonOwnerChangesProgramVKey() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        manager.changeProgramVKey(keccak256("newVKey"));
    }

    // Test setting verifier
    function testSetVerifier() public {
        address newVerifier = makeAddr("newVerifier");
        manager.setVerifier(newVerifier);
        assertEq(manager.verifier(), newVerifier);
    }

    function test_RevertWhen_NonOwnerSetsVerifier() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        manager.setVerifier(makeAddr("newVerifier"));
    }

    function test_RevertWhen_SettingZeroAddressVerifier() public {
        vm.expectRevert("AssetManager: Invalid verifier address");
        manager.setVerifier(address(0));
    }
}