// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../../src/stargate/GemStargateMulticallHandler.sol";

contract GemStargateDeployerScript is Script {
    struct NetworkConfig {
        address endpoint;
    }

    mapping(uint256 => string) private chainToNetworkName;

    constructor() {
        chainToNetworkName[1] = "ETHEREUM";
        chainToNetworkName[10] = "OPTIMISM";
        chainToNetworkName[8453] = "BASE";
        chainToNetworkName[56] = "BSC";
        chainToNetworkName[42161] = "ARBITRUM";
        chainToNetworkName[137] = "POLYGON";
        chainToNetworkName[43114] = "AVALANCHE";
    }

    function getNetworkConfig(
        uint256 chainId
    ) internal view returns (NetworkConfig memory) {
        string memory networkName = chainToNetworkName[chainId];

        // Construct environment variable names
        string memory endpointVar = string.concat(
            "STARGATE_ENDPOINT_",
            networkName
        );

        // Get values from environment
        address endpoint = vm.envAddress(endpointVar);

        return NetworkConfig(endpoint);
    }

    function run() public {
        console.log("Deploying GemStargateMulticallHandler...");
        uint256 chainId = block.chainid;
        console.log("chainId: %s", chainId);
        // Skip unsupported chains
        if (bytes(chainToNetworkName[chainId]).length == 0) {
            console.log(
                "Unsupported chain. Chain ID: %s. Skipping...",
                chainId
            );
            return;
        }

        NetworkConfig memory config = getNetworkConfig(chainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GemStargateMulticallHandler handler = new GemStargateMulticallHandler(
            config.endpoint
        );

        console.log(
            "Deployed GemStargateMulticallHandler for Stargate %s at %s",
            config.endpoint,
            address(handler)
        );

        vm.stopBroadcast();
    }
}
