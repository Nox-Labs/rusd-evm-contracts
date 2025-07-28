// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Deploy} from "./Deploy.s.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

import {RUSDOmnichainAdapter} from "../src/RUSDOmnichainAdapter.sol";

contract WireOApps is Deploy {
    /**
     * @notice Wire EVM chains
     * @param chains List of chains to wire
     * @dev This function will wire all evm chains with each other
     */
    function wireEVM(uint32[] memory chains) public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        RUSDOmnichainAdapter adapter =
            RUSDOmnichainAdapter(readContractAddress(MAIN_CHAIN_ID, "RUSDOmnichainAdapter"));
        for (uint256 i = 0; i < chains.length; i++) {
            fork(chains[i]);
            for (uint256 j = 0; j < chains.length; j++) {
                if (i == j) continue;
                uint32 remoteEid = getEid(chains[j]);
                vm.broadcast(pk);
                adapter.setPeer(remoteEid, OFTMsgCodec.addressToBytes32(address(adapter)));
            }
        }
    }

    /**
     * @notice Wire Solana chain
     * @param chains List of chains to wire
     * @param solanaOftStoreAddress Solana OFT store address
     * @param solanaChainId Solana chain id mainnet/devnet (see layerzero docs)
     * @dev This function will wire all evm chains with Solana
     */
    function wireSolana(uint32[] memory chains, bytes32 solanaOftStoreAddress, uint32 solanaChainId)
        public
    {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        RUSDOmnichainAdapter adapter =
            RUSDOmnichainAdapter(readContractAddress(MAIN_CHAIN_ID, "RUSDOmnichainAdapter"));

        for (uint256 i = 0; i < chains.length; i++) {
            fork(chains[i]);
            uint32 solanaEid = getEid(solanaChainId);
            vm.broadcast(pk);
            adapter.setPeer(solanaEid, solanaOftStoreAddress);
        }
    }
}
