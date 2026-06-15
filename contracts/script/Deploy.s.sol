// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {LogersAccount} from "../src/LogersAccount.sol";
import {LogersAccountFactory} from "../src/LogersAccountFactory.sol";
import {LogersPaymaster} from "../src/LogersPaymaster.sol";
import {LogersPriceOracle} from "../src/oracle/LogersPriceOracle.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {DeployConfig} from "./DeployConfig.sol";

/// @notice Deploy all LogersWallet contracts to Base Sepolia (or local anvil).
///         Writes deployed addresses to broadcast/deployment.json for SDK consumption.
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== LogersWallet Deployment ===");
        console2.log("Deployer:   ", deployer);
        console2.log("Chain ID:   ", block.chainid);
        console2.log("EntryPoint: ", DeployConfig.ENTRYPOINT);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Price Oracle
        LogersPriceOracle oracle = new LogersPriceOracle(deployer);
        console2.log("LogersPriceOracle:", address(oracle));

        // Register USDC feed if address provided (skip on anvil or if feed is zero)
        if (DeployConfig.USDC_ETH_FEED != address(0) && block.chainid != 31_337) {
            oracle.addFeed(DeployConfig.USDC_ADDRESS, DeployConfig.USDC_ETH_FEED);
            console2.log("  Registered USDC/ETH feed");
        }

        // 2. Deploy Factory (deploys shared implementation internally)
        LogersAccountFactory factory =
            new LogersAccountFactory(IEntryPoint(DeployConfig.ENTRYPOINT), deployer);
        console2.log("LogersAccountFactory:", address(factory));
        console2.log("  Implementation:    ", address(factory.accountImplementation()));

        // 3. Deploy Paymaster
        LogersPaymaster paymaster =
            new LogersPaymaster(IEntryPoint(DeployConfig.ENTRYPOINT), oracle, deployer);
        console2.log("LogersPaymaster:", address(paymaster));

        // Whitelist USDC for ERC-20 gas payments
        if (DeployConfig.USDC_ADDRESS != address(0)) {
            paymaster.whitelistToken(DeployConfig.USDC_ADDRESS);
            console2.log("  Whitelisted USDC for gas payments");
        }

        // 4. Deposit ETH to paymaster (skip on local anvil)
        if (block.chainid != 31_337) {
            paymaster.deposit{value: DeployConfig.INITIAL_PAYMASTER_DEPOSIT}();
            console2.log("  Deposited", DeployConfig.INITIAL_PAYMASTER_DEPOSIT, "wei to paymaster");
        }

        vm.stopBroadcast();

        // 5. Write addresses to JSON for SDK consumption
        string memory json = string(
            abi.encodePacked(
                '{"factory":"',
                vm.toString(address(factory)),
                '","paymaster":"',
                vm.toString(address(paymaster)),
                '","oracle":"',
                vm.toString(address(oracle)),
                '","implementation":"',
                vm.toString(address(factory.accountImplementation())),
                '","entrypoint":"',
                vm.toString(DeployConfig.ENTRYPOINT),
                '","chainId":',
                vm.toString(block.chainid),
                "}"
            )
        );
        vm.writeFile("./broadcast/deployment.json", json);
        console2.log(unicode"\n✅ Addresses written to broadcast/deployment.json");
    }
}
