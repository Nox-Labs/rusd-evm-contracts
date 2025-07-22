// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {ChainsRegistry} from "./Chains.sol";

contract Fork is ChainsRegistry {
    Vm private vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Created because forkId can be 0 and cannot be used to prove fork existence
    struct ForkData {
        uint256 forkId;
        bool exists;
    }

    mapping(uint256 => ForkData) private _forkId;

    function fork(uint256 chainId) public {
        ForkData memory forkData = _forkId[chainId];

        try vm.activeFork() returns (uint256 currentForkId) {
            // If we already have an active fork for this chain, just return
            if (forkData.exists && currentForkId == forkData.forkId) {
                return;
            }
        } catch {
            // No active fork, continue with creation/selection
        }

        // If fork exists but not active, select it
        if (forkData.exists) {
            vm.selectFork(forkData.forkId);
            return;
        }

        // Create new fork
        string memory forkAlias = getChainAlias(chainId);
        uint256 newForkId = vm.createFork(forkAlias);
        _forkId[chainId] = ForkData(newForkId, true);
        vm.selectFork(newForkId);
    }
}
