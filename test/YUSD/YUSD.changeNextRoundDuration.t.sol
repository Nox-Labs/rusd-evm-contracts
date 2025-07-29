// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract ChangeNextRoundDuration is YUSDSetup {
    function test_ShouldChangeNextRoundDuration() public {
        uint32 newDuration = 30 days;

        yusd.changeNextRoundDuration(newDuration);

        (, uint32 duration,) = yusd.getRoundInfo(currentRoundId + 1);

        assertEq(duration, newDuration);
    }

    function test_ShouldEmitEvent() public {
        uint32 newDuration = 30 days;

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundDurationChanged(currentRoundId + 1, newDuration);
        yusd.changeNextRoundDuration(newDuration);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        yusd.changeNextRoundDuration(30 days);
    }
}
