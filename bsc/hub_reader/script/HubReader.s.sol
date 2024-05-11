// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/HubReader.sol";

contract HubReaderScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        HubReader reader = new HubReader();
        console.log("HubReader deployed to:", address(reader));
        vm.stopBroadcast();
    }
}
