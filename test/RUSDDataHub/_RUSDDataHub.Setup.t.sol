// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "test/BaseSetup.sol";

contract RUSDDataHubSetup is BaseSetup {
    RUSDDataHubMainChain public newRUSDDataHub;

    address mockAddress = makeAddr("mockAddress");

    function _afterSetUp() internal override {
        address _create3Factory = Create3Deployer._deploy_create3Factory("RUSD.CREATE3Factory.2");
        newRUSDDataHub = RUSDDataHubMainChain(
            RusdDeployer.deploy_RUSDDataHubMainChain(_create3Factory, address(this), address(this))
        );
    }
}
