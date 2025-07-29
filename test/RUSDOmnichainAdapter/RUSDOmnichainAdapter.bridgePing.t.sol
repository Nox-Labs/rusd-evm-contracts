// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDOmnichainAdapter.Setup.t.sol";

contract BridgePing is RUSDOmnichainAdapterSetup {
    function testFuzz_ShouldTransferRUSDFromAtoB(uint256 amount) public {
        _checkFuzzAssumptions(amount);

        uint256 balanceBeforeA = rusd.balanceOf(address(this));
        uint256 balanceBeforeB = rusd2.balanceOf(address(this));
        uint256 totalSupplyABefore = rusd.totalSupply();
        uint256 totalSupplyBBefore = rusd2.totalSupply();

        _bridge(endPointB, adapter2, amount);

        uint256 balanceAfterA = rusd.balanceOf(address(this));
        uint256 balanceAfterB = rusd2.balanceOf(address(this));
        uint256 totalSupplyAAfter = rusd.totalSupply();
        uint256 totalSupplyBAfter = rusd2.totalSupply();

        assertEq(balanceAfterA, balanceBeforeA - amount);
        assertEq(balanceAfterB, balanceBeforeB + amount);
        assertEq(totalSupplyAAfter, totalSupplyABefore - amount);
        assertEq(totalSupplyBAfter, totalSupplyBBefore + amount);
    }

    function test_RevertIfPaused() public {
        Message memory bridgePayload = Message(addressToBytes32(address(1)), uint64(1));
        MessagingFee memory fee = MessagingFee(1, 1);

        rusdDataHub.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        adapter.bridgePing(bridgePayload, LzMessageMetadata(1, "", address(1), fee));
    }

    function test_ShouldEmitEvent() public {
        Message memory message = Message(addressToBytes32(address(this)), uint64(1));
        MessagingFee memory fee =
            adapter.quoteSend(endPointB.eid(), message, adapter.defaultLzOptions(), false);
        LzMessageMetadata memory metadata =
            LzMessageMetadata(endPointB.eid(), adapter.defaultLzOptions(), address(this), fee);

        vm.expectEmit(false, false, false, false);
        emit IRUSDOmnichainAdapter.BridgePing(bytes32(0), address(0), message, metadata);
        adapter.bridgePing{value: fee.nativeFee}(message, metadata);
    }
}
