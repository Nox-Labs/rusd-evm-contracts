// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract FinalizeRound is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(this), MINT_AMOUNT * 100, mockData);
        rusd.mint(address(yusd), MINT_AMOUNT * 100, mockData);
    }

    function testFuzz_ShouldFinalizeRound(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);
        yusd.stake(address(this), uint96(amount), mockData);
        skip(roundDuration);

        uint256 balanceBeforeAdmin = rusd.balanceOf(address(this));
        uint256 balanceBeforeYUSD = rusd.balanceOf(address(yusd));

        yusd.finalizeRound(currentRoundId);

        uint256 balanceAfterAdmin = rusd.balanceOf(address(this));
        uint256 balanceAfterYUSD = rusd.balanceOf(address(yusd));

        uint256 totalRewards = yusd.calculateTotalRewardsRound(currentRoundId);

        assertEq(balanceAfterAdmin, balanceBeforeAdmin - totalRewards);
        assertEq(balanceAfterYUSD, balanceBeforeYUSD + totalRewards);

        (,, bool isFinalized) = yusd.getRoundInfo(currentRoundId);

        assertEq(isFinalized, true);
    }

    function test_RevertIfRoundNotEnded() public {
        vm.expectRevert(IYUSD.RoundNotEnded.selector);
        yusd.finalizeRound(currentRoundId);
    }

    function test_RevertIfTwabNotFinalized() public {
        uint32 breakDuration = 1000; // in base setup roundDuration end timestamp and twab finalize observation is the same, we need to break this to test the revert

        yusd.changeNextRoundDuration(roundDuration + breakDuration);
        skip(roundDuration);
        yusd.finalizeRound(currentRoundId);
        yusd.stake(address(this), MINT_AMOUNT, mockData);
        skip(roundDuration + breakDuration);

        vm.expectRevert(IYUSD.TwabNotFinalized.selector);
        yusd.finalizeRound(currentRoundId + 1);
    }

    function test_ShouldEmitEvent() public {
        skip(roundDuration);

        uint256 totalRewards = yusd.calculateTotalRewardsRound(currentRoundId);

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundFinalized(currentRoundId, totalRewards);
        yusd.finalizeRound(currentRoundId);
    }
}
