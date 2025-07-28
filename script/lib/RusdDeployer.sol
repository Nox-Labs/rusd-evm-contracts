// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {RUSD} from "../../src/RUSD.sol";
import {YUSD} from "../../src/YUSD.sol";
import {RUSDDataHubMainChain, RUSDDataHub} from "../../src/RUSDDataHub.sol";
import {RUSDOmnichainAdapter} from "../../src/RUSDOmnichainAdapter.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Create3Deployer} from "./Create3Deployer.sol";

library RusdDeployer {
    using Create3Deployer for address;

    function deploy_RUSDDataHub(address factory, address defaultAdmin, address minter)
        internal
        returns (address rusdDataHub)
    {
        address implementation = address(new RUSDDataHub());

        rusdDataHub = factory.create3Deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                implementation, abi.encodeCall(RUSDDataHub.initialize, (defaultAdmin, minter))
            ),
            "RUSDDataHub"
        );
    }

    function deploy_RUSDDataHubMainChain(address factory, address defaultAdmin, address minter)
        internal
        returns (address rusdDataHub)
    {
        address implementation = address(new RUSDDataHubMainChain());

        rusdDataHub = factory.create3Deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                implementation, abi.encodeCall(RUSDDataHub.initialize, (defaultAdmin, minter))
            ),
            "RUSDDataHubMainChain"
        );
    }

    function deploy_RUSD(address factory, address rusdDataHub) internal returns (address rusd) {
        address implementation = address(new RUSD());

        rusd = factory.create3Deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, abi.encodeCall(RUSD.initialize, (rusdDataHub))),
            "RUSD"
        );
    }

    function deploy_YUSD(
        address factory,
        address rusdDataHub,
        uint32 periodLength,
        uint32 firstRoundStartTimestamp,
        uint32 roundBp,
        uint32 roundDuration
    ) internal returns (address yusd) {
        address implementation = address(new YUSD());

        yusd = factory.create3Deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                implementation,
                abi.encodeCall(
                    YUSD.initialize,
                    (rusdDataHub, periodLength, firstRoundStartTimestamp, roundBp, roundDuration)
                )
            ),
            "YUSD"
        );
    }

    function deploy_RUSDOmnichainAdapter(address factory, address rusdDataHub, address lzEndpoint)
        internal
        returns (address omnichainAdapter)
    {
        address implementation = address(new RUSDOmnichainAdapter(lzEndpoint));

        omnichainAdapter = factory.create3Deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                implementation, abi.encodeCall(RUSDOmnichainAdapter.initialize, (rusdDataHub))
            ),
            "RUSDOmnichainAdapter"
        );
    }
}
