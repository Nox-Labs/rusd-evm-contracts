// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {RUSD, IRUSD} from "../../src/RUSD.sol";
import {YUSD, IYUSD} from "../../src/YUSD.sol";
import {
    RUSDDataHubMainChain,
    RUSDDataHub,
    IRUSDDataHubMainChain,
    IRUSDDataHub
} from "../../src/RUSDDataHub.sol";
import {RUSDOmnichainAdapter, IRUSDOmnichainAdapter} from "../../src/RUSDOmnichainAdapter.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create3Deployer} from "./Create3Deployer.sol";

import {ICREATE3Factory} from "@layerzerolabs/create3-factory/contracts/ICREATE3Factory.sol";

library RusdDeployer {
    using Create3Deployer for ICREATE3Factory;

    function deploy_RUSDDataHub(ICREATE3Factory factory, address defaultAdmin, address minter)
        internal
        returns (RUSDDataHub rusdDataHub)
    {
        address implementation = address(new RUSDDataHub());

        rusdDataHub = RUSDDataHub(
            factory.create3Deploy(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    implementation, abi.encodeCall(RUSDDataHub.initialize, (defaultAdmin, minter))
                ),
                "RUSDDataHub"
            )
        );
    }

    function deploy_RUSDDataHubMainChain(
        ICREATE3Factory factory,
        address defaultAdmin,
        address minter
    ) internal returns (RUSDDataHubMainChain rusdDataHub) {
        address implementation = address(new RUSDDataHubMainChain());

        rusdDataHub = RUSDDataHubMainChain(
            factory.create3Deploy(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    implementation, abi.encodeCall(RUSDDataHub.initialize, (defaultAdmin, minter))
                ),
                "RUSDDataHubMainChain"
            )
        );
    }

    function deploy_RUSD(ICREATE3Factory factory, IRUSDDataHub rusdDataHub)
        internal
        returns (RUSD rusd)
    {
        address implementation = address(new RUSD());

        rusd = RUSD(
            factory.create3Deploy(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation, abi.encodeCall(RUSD.initialize, (rusdDataHub))),
                "RUSD"
            )
        );
    }

    function deploy_YUSD(
        ICREATE3Factory factory,
        IRUSDDataHub rusdDataHub,
        uint32 periodLength,
        uint32 firstRoundStartTimestamp,
        uint32 roundBp,
        uint32 roundDuration
    ) internal returns (YUSD yusd) {
        address implementation = address(new YUSD());

        yusd = YUSD(
            factory.create3Deploy(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    implementation,
                    abi.encodeCall(
                        YUSD.initialize,
                        (
                            rusdDataHub,
                            periodLength,
                            firstRoundStartTimestamp,
                            roundBp,
                            roundDuration
                        )
                    )
                ),
                "YUSD"
            )
        );
    }

    function deploy_RUSDOmnichainAdapter(
        ICREATE3Factory factory,
        IRUSDDataHub rusdDataHub,
        address lzEndpoint
    ) internal returns (RUSDOmnichainAdapter omnichainAdapter) {
        address implementation = address(new RUSDOmnichainAdapter(lzEndpoint));

        omnichainAdapter = RUSDOmnichainAdapter(
            factory.create3Deploy(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    implementation, abi.encodeCall(RUSDOmnichainAdapter.initialize, (rusdDataHub))
                ),
                "RUSDOmnichainAdapter"
            )
        );
    }
}
