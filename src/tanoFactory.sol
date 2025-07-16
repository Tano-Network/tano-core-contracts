// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AssetManager.sol";

/**
 * @title AssetManagerFactory
 * @dev A factory for deploying new AssetManager contracts.
 */
contract TanoFactory {
    address[] public deployedAssetManagers;

    event AssetManagerCreated(address indexed managerAddress, address indexed owner, address indexed tokenAddress);

    /**
     * @dev Deploys a new AssetManager contract.
     * The caller (msg.sender) will become the owner of the new AssetManager.
     * @param tokenAddress The address of the MyToken contract for the new manager.
     * @return managerAddress The address of the newly created AssetManager.
     */
    function createAssetManager(address tokenAddress) external returns (address managerAddress) {
        require(tokenAddress != address(0), "Factory: Invalid token address");
        
        // The creator of the manager becomes its owner
        AssetManager manager = new AssetManager(tokenAddress, msg.sender);
        managerAddress = address(manager);
        
        deployedAssetManagers.push(managerAddress);
        
        emit AssetManagerCreated(managerAddress, msg.sender, tokenAddress);
    }

    function getAssetManagers() external view returns (address[] memory) {
        return deployedAssetManagers;
    }

    function getAssetManagerCount() external view returns (uint256) {
        return deployedAssetManagers.length;
    }

    function getAssetManagerAtIndex(uint256 index) external view returns (address) {
        require(index < deployedAssetManagers.length, "Factory: Index out of bounds");
        return deployedAssetManagers[index];
    }
}