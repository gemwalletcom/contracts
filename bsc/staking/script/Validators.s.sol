// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/Validators.sol";

contract ValidatorsScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ValidatorsReader reader = new ValidatorsReader();
        console.log("ValidatorsReader deployed to:", address(reader));
        vm.stopBroadcast();
    }
}
