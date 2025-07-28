// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {FileHelpers} from "../test/_utils/FileHelpers.sol";
import {Fork} from "../test/_utils/Fork.sol";

import {RusdDeployer} from "./lib/RusdDeployer.sol";

import {RUSDDataHub, RUSDDataHubMainChain} from "../src/RUSDDataHub.sol";
import {RUSD} from "../src/RUSD.sol";
import {YUSD} from "../src/YUSD.sol";

contract Upgrade is Script, FileHelpers, Fork {
    using RusdDeployer for address;

    uint256 pk;

    function setUp() public {
        pk = vm.envUint("PRIVATE_KEY");
    }

    function run(uint32 chainId) public {
        fork(chainId);

        // _upgradeRUSD();
        _upgradeYUSD();
        // _upgradeRUSDDataHub();
        // _upgradeRUSDDataHubMainChain();
    }

    function _upgradeRUSDDataHub() internal {
        address rusdDataHub = readContractAddress(block.chainid, "RUSDDataHub");

        try RUSDDataHubMainChain(rusdDataHub).getYUSD() returns (address) {
            revert("This upgrade should be done with RUSDDataHubMainChain");
        } catch {}

        vm.startBroadcast(pk);
        address newImplementation = address(new RUSDDataHub());
        RUSDDataHub(rusdDataHub).upgradeToAndCall(newImplementation, "");
        vm.stopBroadcast();
    }

    function _upgradeRUSDDataHubMainChain() internal {
        address rusdDataHub = readContractAddress(block.chainid, "RUSDDataHub");

        try RUSDDataHubMainChain(rusdDataHub).getYUSD() returns (address) {}
        catch {
            revert("This upgrade should be done with RUSDDataHub");
        }

        vm.startBroadcast(pk);
        address newImplementation = address(new RUSDDataHubMainChain());
        RUSDDataHubMainChain(rusdDataHub).upgradeToAndCall(newImplementation, "");
        vm.stopBroadcast();
    }

    function _upgradeRUSD() internal {
        address rusd = readContractAddress(block.chainid, "RUSD");

        vm.startBroadcast(pk);
        address newImplementation = address(new RUSD());
        RUSD(rusd).upgradeToAndCall(newImplementation, "");
        vm.stopBroadcast();
    }

    function _upgradeYUSD() internal {
        address yusd = readContractAddress(block.chainid, "YUSD");

        vm.startBroadcast(pk);
        address newImplementation = address(new YUSD());
        YUSD(yusd).upgradeToAndCall(newImplementation, "");
        vm.stopBroadcast();
    }
}
