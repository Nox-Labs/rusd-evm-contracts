// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract ChangeNextRoundApr is YUSDSetup {
    function test_ShouldChangeNextRoundApr() public {
        uint32 newApr = 1000;

        yusd.changeNextRoundApr(newApr);

        assertEq(yusd.nextRoundApr(), newApr);
    }

    function test_ShouldEmitRoundAprChanged() public {
        uint32 newApr = 1000;

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundAprChanged(newApr);
        yusd.changeNextRoundApr(newApr);
    }
}
