// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract ChangeNextRoundBp is YUSDSetup {
    function test_ShouldChangeNextRoundBp() public {
        uint32 newBp = 1000;

        yusd.changeNextRoundBp(newBp);

        (uint32 nextBp,,) = yusd.getRoundInfo(currentRoundId + 1);

        assertEq(nextBp, newBp);
    }

    function test_ShouldEmitEvent() public {
        uint32 newBp = 1000;

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundBpChanged(currentRoundId + 1, newBp);
        yusd.changeNextRoundBp(newBp);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        yusd.changeNextRoundBp(1000);
    }
}
