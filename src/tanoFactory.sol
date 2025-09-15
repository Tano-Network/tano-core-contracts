// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AssetManager.sol";
import {ItAsset} from "./interface/ItAsset.sol";

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
    function createAssetManager(address tokenAddress, address _verifier,bytes32 _ProgramVKey) external returns (address managerAddress) {
        require(tokenAddress != address(0), "Factory: Invalid token address");
        
        // The creator of the manager becomes its owner
        AssetManager manager = new AssetManager(tokenAddress, msg.sender,_verifier, _ProgramVKey);
        managerAddress = address(manager);
        
        deployedAssetManagers.push(managerAddress);
        ItAsset(tokenAddress).garntMinterRole(managerAddress);
        emit AssetManagerCreated(managerAddress, msg.sender, tokenAddress);
    }

    /**
     * @dev Returns the list of all deployed AssetManager addresses.
     * @return An array of addresses of deployed AssetManager contracts.
     */
    function getAssetManagers() external view returns (address[] memory) {
        return deployedAssetManagers;
    }

    /**
     * @dev Returns the total number of deployed AssetManager contracts.
     * @return The count of deployed AssetManager contracts.
     */
    function getAssetManagerCount() external view returns (uint256) {
        return deployedAssetManagers.length;
    }

    /**
     * @dev Returns the address of the AssetManager at a specific index.
     * @param index The index of the AssetManager in the deployed list.
     * @return The address of the AssetManager at the given index.
     */ 
    function getAssetManagerAtIndex(uint256 index) external view returns (address) {
        require(index < deployedAssetManagers.length, "Factory: Index out of bounds");
        return deployedAssetManagers[index];
    }
}