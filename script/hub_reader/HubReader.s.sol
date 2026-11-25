// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HubReader} from "../../src/hub_reader/HubReader.sol";

contract HubReaderScript is Script {
    function run() public {
        vm.startBroadcast();
        HubReader reader = new HubReader();
        console.log("HubReader deployed to:", address(reader));
        vm.stopBroadcast();
    }
}
