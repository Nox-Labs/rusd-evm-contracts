// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract PayOutRoundRewards is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(this), MINT_AMOUNT * 100, "");
    }

    function testFuzz_ShouldPayOutRoundRewards(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);
        yusd.mint(address(this), amount, "");
        skip(roundDuration);

        uint256 balanceBeforeAdmin = rusd.balanceOf(address(this));
        uint256 balanceBeforeYUSD = rusd.balanceOf(address(yusd));

        yusd.payOutRoundRewards(currentRoundId);

        uint256 balanceAfterAdmin = rusd.balanceOf(address(this));
        uint256 balanceAfterYUSD = rusd.balanceOf(address(yusd));

        uint256 totalRewards = yusd.calculateTotalRewardsRound(currentRoundId);

        assertEq(balanceAfterAdmin, balanceBeforeAdmin - totalRewards);
        assertEq(balanceAfterYUSD, balanceBeforeYUSD + totalRewards);
    }

    function test_RevertIfRoundNotEnded() public {
        yusd.mint(address(this), 1, "");
        skip(roundDuration * 2 - 1);

        yusd.claimRewards(currentRoundId, address(this));

        assertEq(yusd.getCurrentRoundId(), currentRoundId + 1);

        vm.expectRevert(IYUSD.RoundNotEnded.selector);
        yusd.payOutRoundRewards(1);
    }

    function test_ShouldEmitRoundRewardsPaidOut() public {
        skip(roundDuration);

        uint256 totalRewards = yusd.calculateTotalRewardsRound(currentRoundId);

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundRewardsPaidOut(currentRoundId, totalRewards);
        yusd.payOutRoundRewards(currentRoundId);
    }
}
