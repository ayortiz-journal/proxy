// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Proxy.sol";

contract Deploy is Script {
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");
        bool mainnet = vm.envOr("MAINNET", false);

        vm.startBroadcast(pk);
        Proxy proxy = new Proxy(mainnet ? USDC_BASE : USDC_BASE_SEPOLIA, treasury);
        vm.stopBroadcast();

        console.log("Proxy deployed:", address(proxy));
    }
}
