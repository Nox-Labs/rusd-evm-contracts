// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract CompoundRewards is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(yusd), MINT_AMOUNT * 100, mockData);

        yusd.stake(address(this), MINT_AMOUNT, mockData);
        (, uint32 end) = yusd.getRoundPeriod(currentRoundId);
        vm.warp(end);
        _finalizeCurrentRound();
    }

    function test_ShouldCompoundAllRewardsForRound() public {
        uint256 claimableRewards = yusd.calculateClaimableRewards(currentRoundId, address(this));

        uint256 yusdBalanceBefore = yusd.balanceOf(address(this));
        uint256 rusdBalanceBefore = rusd.balanceOf(address(this));
        yusd.compoundRewards(currentRoundId, address(this));
        uint256 yusdBalanceAfter = yusd.balanceOf(address(this));
        uint256 rusdBalanceAfter = rusd.balanceOf(address(this));

        assertEq(rusdBalanceAfter, rusdBalanceBefore);
        assertEq(yusdBalanceAfter, yusdBalanceBefore + claimableRewards);
    }

    function test_RevertIfNotMinter() public {
        vm.expectRevert(Base.Unauthorized.selector);
        vm.prank(user);
        yusd.compoundRewards(currentRoundId, address(this));
    }

    function test_ShouldEmitEvent() public {
        uint256 rewards = yusd.calculateClaimableRewards(currentRoundId, address(this));

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RewardsCompounded(currentRoundId, address(this), rewards);
        yusd.compoundRewards(currentRoundId, address(this));
    }

    function test_RevertIfHighPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        yusd.compoundRewards(currentRoundId, address(this));
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRound() public test_roundTimestampModifier {
        yusd.compoundRewards(currentRoundId, address(this));
    }
}
