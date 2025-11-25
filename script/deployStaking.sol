pragma solidity ^0.8.20;


// import "../src/assetManager.sol";
import {StakingModule} from "../src/stakingModule.sol";
import {Script} from "../lib/forge-std/src/Script.sol";

contract DeployScript is Script {


    address stakingToken = 0x46507E8929Fe9C20c8914fc9036829F6e7740D9D; // Replace with actual factory address
    address rewardToken = 0x46507E8929Fe9C20c8914fc9036829F6e7740D9D; // Replace with actual reward token address
function run() external returns (address) {
        vm.startBroadcast();
        // Deploy the token contract
        StakingModule staking = new StakingModule(stakingToken, rewardToken);
        vm.stopBroadcast();
        return (address(staking));
}
}


