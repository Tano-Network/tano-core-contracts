pragma solidity ^0.8.20;


// import "../src/assetManager.sol";
import "../src/tAsset.sol";
import "../src/tanofactory.sol";
import "../lib/forge-std/src/Script.sol";

contract DeployScript is Script {


    string tokenName = "Tano Token";
    string tokenSymbol = "TANO";

    address verifier = 0x3B6041173B80E77f038f3F2C0f9744f04837185e; // Replace with actual verifier address
    bytes32 programVKey = 0x0056d38b7c56e3af567ff96d8e335eb07668a7d3888fbfe67994c1df60f99402; // Replace with actual program VKey
function run() external returns (address,address) {
        vm.startBroadcast();
        // Deploy the token contract
        // tAsset token = new tAsset(tokenName, tokenSymbol);
        // Grant the MINTER_ROLE to the deployer
        // token.garntMinterRole(msg.sender);
        // Deploy the AssetManager contract using the factory
        TanoFactory factory = new TanoFactory();
        // address managerAddress = factory.createAssetManager(address(token),verifier,programVKey);
        vm.stopBroadcast();
        return (address(factory), address(factory));

}
}


