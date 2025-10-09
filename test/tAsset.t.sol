// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TAsset} from "../src/tAsset.sol";

contract TAssetTest is Test {
    TAsset public token;
    address public admin;
    address public minter;
    address public user;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function setUp() public {
        admin = address(this);
        minter = address(0x1);
        user = address(0x2);
        
        token = new TAsset("Tano Asset", "TASSET");
        
        // Label addresses for better trace output in test logs
        vm.label(admin, "Admin");
        vm.label(minter, "Minter");
        vm.label(user, "User");
    }
    
    // Test initial state
    function testInitialState() public view {
        assertEq(token.name(), "Tano Asset");
        assertEq(token.symbol(), "TASSET");
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));
    }
    
    // Test granting minter role
    function testGrantMinterRole() public {
        token.grantMinterRole(minter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }
    
    // Test minting as minter
    function testMintAsMinter() public {
        token.grantMinterRole(minter);
        
        // Set msg.sender to minter for all subsequent calls until stopPrank is called
        vm.startPrank(minter);
        
        uint256 mintAmount = 1000 * 10**18;
        token.mint(user, mintAmount);
        
        // Reset msg.sender to default
        vm.stopPrank();
        
        assertEq(token.balanceOf(user), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }
    
    // Test minting without minter role (should fail)
    function test_RevertWhen_MintingWithoutMinterRole() public {
        vm.startPrank(user);
        
        // Expect the next call to revert with this specific error message
        vm.expectRevert("MyToken: caller is not a minter");
        token.mint(user, 1000);
        vm.stopPrank();
    }
    
    // Test burning
    function testBurn() public {
        token.grantMinterRole(minter);
        
        // Set msg.sender to minter for the next call only
        vm.prank(minter);
        uint256 mintAmount = 1000 * 10**18;
        token.mint(user, mintAmount);
        
        uint256 burnAmount = 400 * 10**18;
        vm.startPrank(user);
        token.burn(burnAmount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }
    
    // Test burnFrom with approval
    function testBurnFrom() public {
        token.grantMinterRole(minter);
        vm.prank(minter);
        uint256 mintAmount = 1000 * 10**18;
        token.mint(user, mintAmount);
        
        uint256 burnAmount = 300 * 10**18;
        vm.prank(user);
        token.approve(admin, burnAmount);
        
        token.burnFrom(user, burnAmount);
        
        assertEq(token.balanceOf(user), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.allowance(user, admin), 0);
    }
    
    // Test transfer
    function testTransfer() public {
        token.grantMinterRole(minter);
        vm.prank(minter);
        uint256 mintAmount = 1000 * 10**18;
        token.mint(user, mintAmount);
        
        uint256 transferAmount = 250 * 10**18;
        vm.prank(user);
        
        // Expect an event with the first two topics matched, the third ignored, and data matched
        vm.expectEmit(true, true, false, true);
        emit Transfer(user, minter, transferAmount);
        
        require(token.transfer(minter, transferAmount), "transfer failed");
        
        assertEq(token.balanceOf(user), mintAmount - transferAmount);
        assertEq(token.balanceOf(minter), transferAmount);
    }
    
    // Test transferFrom with approval
    function testTransferFrom() public {
        token.grantMinterRole(minter);
        vm.prank(minter);
        uint256 mintAmount = 1000 * 10**18;
        token.mint(user, mintAmount);
        
        uint256 approveAmount = 500 * 10**18;
        vm.prank(user);
        token.approve(admin, approveAmount);
        
        uint256 transferAmount = 350 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(user, minter, transferAmount);
        
        require(token.transferFrom(user, minter, transferAmount), "transferFrom failed");
        
        assertEq(token.balanceOf(user), mintAmount - transferAmount);
        assertEq(token.balanceOf(minter), transferAmount);
        assertEq(token.allowance(user, admin), approveAmount - transferAmount);
    }
    
    // Test revoking minter role
    function testRevokeMinterRole() public {
        token.grantMinterRole(minter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        
        bytes32 minterRole = token.MINTER_ROLE();
        token.revokeRole(minterRole, minter);
        
        assertFalse(token.hasRole(minterRole, minter));
        
        vm.prank(minter);
        vm.expectRevert("MyToken: caller is not a minter");
        token.mint(user, 100);
    }
    
    // Test non-admin cannot grant minter role with specific error message
    function test_RevertWhen_NonAdminGrantsMinterRole() public {
        vm.prank(user);
        vm.expectRevert("MyToken: caller is not an admin");
        token.grantMinterRole(minter);
    }
}