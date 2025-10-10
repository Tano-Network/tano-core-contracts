pragma solidity ^0.8.20;


// import "../src/assetManager.sol";
import {TAsset} from "../src/tAsset.sol";
import {TanoFactory} from "../src/tanofactory.sol";
import {Script} from "../lib/forge-std/src/Script.sol";

contract DeployScript is Script {


    string tokenName = "TANO DOGE";
    string tokenSymbol = "tDOGE";
    address factoryAddress = 0x1158d09f180195E43813B807E5B864f66bEf5f91; // Replace with actual factory address

function run() external returns (address,address) {
        vm.startBroadcast();
        // Deploy the token contract
        TAsset token = new TAsset(tokenName, tokenSymbol);
        // Grant the MINTER_ROLE to the deployer
        token.grantMinterRole(msg.sender);
        // Deploy the AssetManager contract using the factory
        TanoFactory factory = TanoFactory(factoryAddress);
        address managerAddress = factory.createAssetManager(address(token), address(0), bytes32(0), 18);
        vm.stopBroadcast();
        return (address(token), managerAddress);

}
}


