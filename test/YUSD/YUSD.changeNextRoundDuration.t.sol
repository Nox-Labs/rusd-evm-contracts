// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract ChangeNextRoundDuration is YUSDSetup {
    function test_ShouldChangeNextRoundDuration() public {
        uint32 newDuration = 30 days;

        yusd.changeNextRoundDuration(newDuration);

        assertEq(yusd.nextRoundDuration(), newDuration);
    }

    function test_ShouldEmitRoundDurationChanged() public {
        uint32 newDuration = 30 days;

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundDurationChanged(newDuration);
        yusd.changeNextRoundDuration(newDuration);
    }
}
