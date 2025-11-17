// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AssetManager} from "./assetManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AssetManagerFactory
 * @dev A factory for deploying new AssetManager contracts.
 */
contract TanoFactory is Ownable {
    address[] public deployedAssetManagers;
    mapping(address => address) public tokensToManagers;

    event AssetManagerCreated(address indexed managerAddress, address indexed owner, address indexed tokenAddress);


    constructor() Ownable(msg.sender) {}
    /**
     * @dev Deploys a new AssetManager contract.
     * The caller (msg.sender) will become the owner of the new AssetManager.
     * @param tokenAddress The address of the MyToken contract for the new manager.
     * @param verifier The address of the verifier contract.
     * @param programVKey The verification key for the zk-SNARK program.
     * @param nativeTokenDecimals The number of decimals for the native token.
     * @return managerAddress The address of the newly created AssetManager.
     */
    function createAssetManager(address tokenAddress, address verifier, bytes32 programVKey, uint256 nativeTokenDecimals) onlyOwner external returns (address managerAddress) {
        require(tokenAddress != address(0), "Factory: Invalid token address");
        require(tokensToManagers[tokenAddress] == address(0), "Factory: AssetManager for this token already exists");
        // The creator of the manager becomes its owner
        AssetManager manager = new AssetManager(tokenAddress, msg.sender, verifier, programVKey, nativeTokenDecimals);
        managerAddress = address(manager);
        
        deployedAssetManagers.push(managerAddress);
        tokensToManagers[tokenAddress] = managerAddress;
        
        emit AssetManagerCreated(managerAddress, msg.sender, tokenAddress);
    }

    function getAssetManagers() external view returns (address[] memory) {
        return deployedAssetManagers;
    }

    function getAssetManagerByToken(address tokenAddress) external view returns (address) {
        return tokensToManagers[tokenAddress];
    }

    function getAssetManagerCount() external view returns (uint256) {
        return deployedAssetManagers.length;
    }

    function getAssetManagerAtIndex(uint256 index) external view returns (address) {
        require(index < deployedAssetManagers.length, "Factory: Index out of bounds");
        return deployedAssetManagers[index];
    }

    function transferFactoryOwnership(address newOwner) external onlyOwner {
        transferOwnership(newOwner);
    }
}