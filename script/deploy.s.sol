pragma solidity ^0.8.20;


// import "../src/assetManager.sol";
import "../src/tAsset.sol";
import "../src/tanofactory.sol";
import "../lib/forge-std/src/Script.sol";

contract DeployScript is Script {


    string tokenName = "Tano Token";
    string tokenSymbol = "TANO";

function run() external returns (address,address,address) {
        vm.startBroadcast();
        // Deploy the token contract
        tAsset token = new tAsset(tokenName, tokenSymbol);
        // Grant the MINTER_ROLE to the deployer
        token.garntMinterRole(msg.sender);
        // Deploy the AssetManager contract using the factory
        TanoFactory factory = new TanoFactory();
        address managerAddress = factory.createAssetManager(address(token));
        vm.stopBroadcast();
        return (address(token), managerAddress, address(factory));

}
}


