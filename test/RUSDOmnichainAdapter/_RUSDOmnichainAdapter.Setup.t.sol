// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "test/BaseSetup.sol";

contract RUSDOmnichainAdapterSetup is BaseSetup {
    function _checkFuzzAssumptions(uint256 amount) internal pure {
        vm.assume(amount > 0);
        vm.assume(amount < MINT_AMOUNT);
    }

    function _bridge(EndpointV2Mock dstEndpoint, RUSDOmnichainAdapter dstAdapter, uint256 amount)
        internal
    {
        Message memory bridgePayload = Message(addressToBytes32(address(this)), uint64(amount));

        MessagingFee memory fee =
            adapter.quoteSend(dstEndpoint.eid(), bridgePayload, adapter.defaultLzOptions(), false);

        adapter.bridgePing{value: fee.nativeFee}(
            bridgePayload,
            LzMessageMetadata(dstEndpoint.eid(), adapter.defaultLzOptions(), address(this), fee)
        );

        verifyPackets(uint32(dstEndpoint.eid()), addressToBytes32(address(dstAdapter))); // finish bridge
    }
}
