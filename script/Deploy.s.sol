// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {FileHelpers} from "../test/_utils/FileHelpers.sol";
import {Fork} from "../test/_utils/Fork.sol";
import {console} from "forge-std/console.sol";
import {addressToBytes32} from "../test/_utils/LayerZeroDevtoolsHelper.sol";

import "./lib/RusdDeployer.sol";

contract Deploy is Script, FileHelpers, Fork {
    using RusdDeployer for address;

    mapping(uint256 chainId => address lzEndpoint) public lzEndpoints;

    address immutable DEFAULT_ADMIN;
    address immutable MINTER;

    uint32 immutable PERIOD_LENGTH;
    uint32 immutable ROUND_DURATION;
    uint32 immutable ROUND_BP;

    uint32 immutable MAIN_CHAIN_ID;

    uint32 FIRST_ROUND_START_TIMESTAMP;

    uint256 pk;

    constructor() {
        MAIN_CHAIN_ID = 42161;

        pk = vm.envUint("PRIVATE_KEY");

        DEFAULT_ADMIN = vm.addr(pk);
        MINTER = DEFAULT_ADMIN;

        PERIOD_LENGTH = 1 days;
        ROUND_DURATION = 5 days;
        ROUND_BP = 1000;

        lzEndpoints[42161] = 0x1a44076050125825900e736c501f859c50fE728c;
        lzEndpoints[56] = 0x1a44076050125825900e736c501f859c50fE728c;

        lzEndpoints[11155111] = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    }

    function run(uint32 chainId) public {
        fork(chainId);

        FIRST_ROUND_START_TIMESTAMP = uint32(block.timestamp);

        console.log("FIRST_ROUND_START_TIMESTAMP", FIRST_ROUND_START_TIMESTAMP);

        address create3Factory = readContractAddress(chainId, "Create3Factory");
        address lzEndpoint = lzEndpoints[chainId];

        address rusdDataHub;
        address rusd;
        address yusd;
        address omnichainAdapter;

        vm.startBroadcast(pk);

        if (chainId == MAIN_CHAIN_ID) {
            (rusdDataHub, rusd, yusd, omnichainAdapter) =
                _mainChainDeploy(create3Factory, DEFAULT_ADMIN, MINTER, lzEndpoint);
        } else {
            (rusdDataHub, rusd, omnichainAdapter) =
                _peripheralChainDeploy(create3Factory, DEFAULT_ADMIN, MINTER, lzEndpoint);
        }

        RUSDDataHub(rusdDataHub).setRUSD(address(rusd));
        RUSDDataHub(rusdDataHub).setOmnichainAdapter(address(omnichainAdapter));
        if (chainId == MAIN_CHAIN_ID) RUSDDataHubMainChain(rusdDataHub).setYUSD(address(yusd));

        vm.stopBroadcast();

        writeContractAddress(chainId, rusd, "RUSD");
        writeContractAddress(chainId, rusdDataHub, "RUSDDataHub");
        writeContractAddress(chainId, omnichainAdapter, "RUSDOmnichainAdapter");
        if (chainId == MAIN_CHAIN_ID) writeContractAddress(chainId, yusd, "YUSD");

        _afterDeploy();
    }

    function wireOApps(uint32[] memory chains) public virtual {
        RUSDOmnichainAdapter adapter =
            RUSDOmnichainAdapter(readContractAddress(MAIN_CHAIN_ID, "RUSDOmnichainAdapter"));
        for (uint256 i = 0; i < chains.length; i++) {
            fork(chains[i]);
            for (uint256 j = 0; j < chains.length; j++) {
                if (i == j) continue;
                uint32 remoteEid = getEid(chains[j]);
                vm.broadcast(pk);
                adapter.setPeer(remoteEid, addressToBytes32(address(adapter)));
            }
        }
    }

    function _afterDeploy() internal virtual {}

    function _peripheralChainDeploy(
        address create3Factory,
        address defaultAdmin,
        address minter,
        address lzEndpoint
    ) internal returns (address rusdDataHub, address rusd, address omnichainAdapter) {
        rusdDataHub = create3Factory.deploy_RUSDDataHubMainChain(defaultAdmin, minter);
        rusd = create3Factory.deploy_RUSD(rusdDataHub);
        omnichainAdapter = create3Factory.deploy_RUSDOmnichainAdapter(rusdDataHub, lzEndpoint);
    }

    function _mainChainDeploy(
        address create3Factory,
        address defaultAdmin,
        address minter,
        address lzEndpoint
    )
        internal
        returns (address rusdDataHub, address rusd, address yusd, address omnichainAdapter)
    {
        rusdDataHub = create3Factory.deploy_RUSDDataHubMainChain(defaultAdmin, minter);
        rusd = create3Factory.deploy_RUSD(rusdDataHub);
        omnichainAdapter = create3Factory.deploy_RUSDOmnichainAdapter(rusdDataHub, lzEndpoint);
        yusd = create3Factory.deploy_YUSD(
            rusdDataHub, PERIOD_LENGTH, FIRST_ROUND_START_TIMESTAMP, ROUND_BP, ROUND_DURATION
        );
    }
}
