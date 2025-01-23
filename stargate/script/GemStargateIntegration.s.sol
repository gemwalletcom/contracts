// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/GemStargateIntegration.sol";

contract GemStargateIntegrationScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        GemStargateIntegration integration = new GemStargateIntegration();
        console.log(
            "GemStargateIntegration deployed to:",
            address(integration)
        );
        vm.stopBroadcast();
    }
}
