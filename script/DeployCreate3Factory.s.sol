// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {FileHelpers} from "../test/_utils/FileHelpers.sol";
import {Fork} from "../test/_utils/Fork.sol";
import {ChainsRegistry} from "../test/_utils/Chains.sol";

import {Create3Deployer, CREATE3Factory} from "./lib/Create3Deployer.sol";

contract DeployCreate3Factory is Script, FileHelpers, Fork {
    function run(uint32 chainId) public {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        fork(chainId);

        vm.broadcast(pk);

        address create3Factory = Create3Deployer._deploy_create3Factory("___Create3Factory");

        writeContractAddress(chainId, create3Factory, "Create3Factory");
    }
}
