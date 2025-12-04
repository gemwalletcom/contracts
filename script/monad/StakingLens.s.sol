// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script, console} from "forge-std/Script.sol";
import {StakingLens} from "../../src/monad/StakingLens.sol";

contract StakingLensScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        StakingLens lens = new StakingLens();
        console.log("StakingLens deployed to:", address(lens));
        vm.stopBroadcast();
    }
}
