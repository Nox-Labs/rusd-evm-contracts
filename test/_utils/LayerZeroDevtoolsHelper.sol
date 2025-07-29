// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EndpointV2Mock} from
    "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

function addressToBytes32(address _addr) pure returns (bytes32) {
    return bytes32(uint256(uint160(_addr)));
}

contract LayerZeroDevtoolsHelper is TestHelperOz5 {
    EndpointV2Mock public endPointA;
    EndpointV2Mock public endPointB;

    uint32 eidA = 1;
    uint32 eidB = 2;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints();
    }

    function setUpEndpoints() public {
        setUpEndpoints(2, TestHelperOz5.LibraryType.UltraLightNode);

        //enum starts with 1 because inside LZ lib we skip 0 step of iteration
        endPointA = EndpointV2Mock(endpoints[1]);
        endPointB = EndpointV2Mock(endpoints[2]);
    }
}
