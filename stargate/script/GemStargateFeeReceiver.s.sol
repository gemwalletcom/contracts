// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/GemStargateFeeReceiver.sol";

contract GemStargateFeeReceiverScript is Script {
    struct NetworkConfig {
        address endpoint;
        address[] stargateAddresses;
    }

    mapping(uint256 => string) private chainToNetworkName;

    constructor() {
        // Supported networks mapping
        // chainToNetworkName[1] = "ETHEREUM";
        chainToNetworkName[10] = "OPTIMISM";
        // chainToNetworkName[8453] = "BASE";
        // chainToNetworkName[56] = "BNB";
        // chainToNetworkName[42161] = "ARBITRUM";
        // chainToNetworkName[137] = "POLYGON";
        // chainToNetworkName[31337] = "LOCAL";
    }

    function getNetworkConfig(
        uint256 chainId
    ) internal view returns (NetworkConfig memory) {
        string memory networkName = chainToNetworkName[chainId];

        // Construct environment variable names
        string memory endpointVar = string.concat("ENDPOINT_", networkName);
        string memory stargateVar = string.concat(
            "STARGATE_ADDRESSES_",
            networkName
        );

        // Get values from environment
        address endpoint = vm.envAddress(endpointVar);
        string memory stargateJson = vm.envString(stargateVar);

        // Parse JSON array of addresses
        address[] memory stargateAddresses = abi.decode(
            vm.parseJson(stargateJson),
            (address[])
        );

        return NetworkConfig(endpoint, stargateAddresses);
    }

    function run() public {
        uint256 chainId = block.chainid;
        console.log("chainId: %s", chainId);
        require(
            bytes(chainToNetworkName[chainId]).length > 0,
            "Unsupported chain"
        );

        NetworkConfig memory config = getNetworkConfig(chainId);
        require(
            config.stargateAddresses.length > 0,
            "No Stargate addresses configured"
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        for (uint256 i = 0; i < config.stargateAddresses.length; i++) {
            address stargate = config.stargateAddresses[i];
            console.log("stargate: %s", stargate);
            console.log("endpoint: %s", config.endpoint);
            GemStargateFeeReceiver receiver = new GemStargateFeeReceiver(
                config.endpoint,
                stargate
            );
            console.log(
                "Deployed GemStargateFeeReceiver for Stargate %s at %s",
                stargate,
                address(receiver)
            );
        }

        vm.stopBroadcast();
    }
}
