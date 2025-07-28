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
// function _stake(EndpointV2Mock dstEndpoint, RUSDOmnichainAdapter dstAdapter, uint256 amount)
//     internal
// {
//     StakePayload memory stakePayload = StakePayload(address(this), amount);

//     LzMessage memory lzMessage = LzMessage(LzMessageType.STAKE, abi.encode(stakePayload));

//     MessagingFee memory fee =
//         adapter.quoteSend(dstEndpoint.eid(), lzMessage, adapter.defaultLzOptions(), false);

//     adapter.stakePing{value: fee.nativeFee}(
//         stakePayload,
//         LzMessageMetadata(dstEndpoint.eid(), adapter.defaultLzOptions(), fee, false)
//     );

//     verifyPackets(uint32(dstEndpoint.eid()), addressToBytes32(address(dstAdapter))); // finish stake
// }
