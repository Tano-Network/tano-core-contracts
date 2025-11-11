// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TanoFactory} from "../src/tanoFactory.sol";
import {TAsset} from "../src/tAsset.sol";
import {AssetManager} from "../src/assetManager.sol";

contract TanoFactoryTest is Test {
    TanoFactory public factory;
    TAsset public token;
    address public admin;
    address public user;
    address public verifier;
    
    event AssetManagerCreated(address indexed managerAddress, address indexed owner, address indexed tokenAddress);
    
    function setUp() public {
        admin = address(this);
        user = address(0x1);
        verifier = makeAddr("verifier");
        
        token = new TAsset("Tano Asset", "TASSET");
        factory = new TanoFactory();
        
        // Label addresses for better trace output
        vm.label(admin, "Admin");
        vm.label(user, "User");
        vm.label(address(token), "Token");
        vm.label(address(factory), "Factory");
        vm.label(verifier, "Verifier");
    }
    
    // Test initial state
    function testInitialState() public view {
        assertEq(factory.getAssetManagerCount(), 0);
    }
    
    // Test creating an asset manager
    function testCreateAssetManager() public {
        address managerAddress = factory.createAssetManager(address(token), verifier, bytes32(0), 18);
        
        // Verify asset manager was created and stored
        assertEq(factory.getAssetManagerCount(), 1);
        assertEq(factory.getAssetManagers()[0], managerAddress);
        assertEq(factory.deployedAssetManagers(0), managerAddress);
        assertEq(factory.getAssetManagerAtIndex(0), managerAddress);
        
        // Verify asset manager properties
        AssetManager manager = AssetManager(managerAddress);
        assertEq(address(manager.TOKEN()), address(token));
        assertEq(manager.owner(), admin);
    }
    
    // Test creating multiple asset managers
    function testCreateMultipleAssetManagers() public {
        // Create first asset manager as admin
        address manager1 = factory.createAssetManager(address(token), verifier, bytes32(0), 18);
        
        // Create second asset manager as user
        vm.prank(admin);
        vm.expectRevert("Factory: AssetManager for this token already exists");
        address manager2 = factory.createAssetManager(address(token), verifier, bytes32(0), 18);

        // Verify asset managers were created and stored
        assertEq(factory.getAssetManagerCount(), 1);
        address[] memory managers = factory.getAssetManagers();
        assertEq(managers[0], manager1);
        // Verify asset managers were created and stored

        AssetManager firstManager = AssetManager(manager1);
        assertEq(firstManager.owner(), admin);
    }

    function testRevert_WhenCreateAssetManagerFromNonOwner() public {
        // Create first asset manager as admin
        address manager1 = factory.createAssetManager(address(token), verifier, bytes32(0), 18);
        
        // Create second asset manager as user
        vm.prank(user);
        vm.expectRevert("OwnableUnauthorizedAccount(0x0000000000000000000000000000000000000001)");
        factory.createAssetManager(address(token), verifier, bytes32(0), 18);

        // Verify asset managers were created and stored
        assertEq(factory.getAssetManagerCount(), 1);
        address[] memory managers = factory.getAssetManagers();
        assertEq(managers[0], manager1);
        
        // Verify each asset manager has the correct owner
        AssetManager firstManager = AssetManager(manager1);
        assertEq(firstManager.owner(), admin);

    }
    
    // Test creating an asset manager with invalid token address
    function test_RevertWhen_CreatingManagerWithZeroAddress() public {
        vm.expectRevert("Factory: Invalid token address");
        factory.createAssetManager(address(0), verifier, bytes32(0), 18);
    }
    
    // Test accessing asset manager at invalid index
    function test_RevertWhen_AccessingInvalidIndex() public {
        factory.createAssetManager(address(token), verifier, bytes32(0), 18);
        
        vm.expectRevert("Factory: Index out of bounds");
        factory.getAssetManagerAtIndex(1);
    }
    
    // Test full integration with asset manager functionality
    function testIntegrationWithAssetManager() public {
        address managerAddress = factory.createAssetManager(address(token), verifier, bytes32(0), 18);
        AssetManager manager = AssetManager(managerAddress);
        
        // Grant minter role to the asset manager
        token.grantMinterRole(managerAddress);
        
        // Set up whitelist for user
        uint256 allowance = 1000 * 10**18;
        manager.setWhitelist(user, allowance);
        
        // User mints tokens
        vm.prank(user);
        manager.mint(500 * 10**18);
        
        // Verify tokens were minted
        assertEq(token.balanceOf(user), 500 * 10**18);
    }

}