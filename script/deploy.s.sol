pragma solidity ^0.8.20;


// import "../src/assetManager.sol";
import {TAsset} from "../src/tAsset.sol";
import {TanoFactory} from "../src/tanofactory.sol";
import {Script} from "../lib/forge-std/src/Script.sol";

contract DeployScript is Script {


    string tokenName = "Tano Token";
    string tokenSymbol = "TANO";

function run() external returns (address,address,address) {
        vm.startBroadcast();
        // Deploy the token contract
        TAsset token = new TAsset(tokenName, tokenSymbol);
        // Grant the MINTER_ROLE to the deployer
        token.grantMinterRole(msg.sender);
        // Deploy the AssetManager contract using the factory
        TanoFactory factory = new TanoFactory();
        address managerAddress = factory.createAssetManager(address(token), address(0), bytes32(0), 18);
        vm.stopBroadcast();
        return (address(token), managerAddress, address(factory));

}
}


