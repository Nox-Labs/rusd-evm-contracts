// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract FinalizeRound is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(this), MINT_AMOUNT * 100, mockData);
        rusd.mint(address(yusd), MINT_AMOUNT * 100, mockData);
    }

    function testFuzz_ShouldPayOutRoundRewards(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);
        yusd.stake(address(this), amount, mockData);
        skip(roundDuration);

        uint256 balanceBeforeAdmin = rusd.balanceOf(address(this));
        uint256 balanceBeforeYUSD = rusd.balanceOf(address(yusd));

        yusd.finalizeRound(currentRoundId);

        uint256 balanceAfterAdmin = rusd.balanceOf(address(this));
        uint256 balanceAfterYUSD = rusd.balanceOf(address(yusd));

        uint256 totalRewards = yusd.calculateTotalRewardsRound(currentRoundId);

        assertEq(balanceAfterAdmin, balanceBeforeAdmin - totalRewards);
        assertEq(balanceAfterYUSD, balanceBeforeYUSD + totalRewards);
    }

    function test_RevertIfRoundNotEnded() public {
        yusd.stake(address(this), 1, mockData);
        skip(roundDuration * 2 - 1);

        yusd.claimRewards(currentRoundId, address(this), address(this));

        assertEq(yusd.getCurrentRoundId(), currentRoundId + 1);

        vm.expectRevert(IYUSD.RoundNotEnded.selector);
        yusd.finalizeRound(1);
    }

    function test_ShouldEmitRoundRewardsPaidOut() public {
        skip(roundDuration);

        uint256 totalRewards = yusd.calculateTotalRewardsRound(currentRoundId);

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RoundFinalized(currentRoundId, totalRewards);
        yusd.finalizeRound(currentRoundId);
    }
}
