// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract CompoundRewards is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(yusd), MINT_AMOUNT * 100, "");

        yusd.mint(address(this), MINT_AMOUNT, "");
        (, uint32 end) = yusd.getRoundPeriod(currentRoundId);
        vm.warp(end);
    }

    function test_ShouldCompoundAllRewardsForRound() public {
        uint256 claimableRewards = yusd.calculateClaimableRewards(currentRoundId, address(this));

        uint256 yusdBalanceBefore = yusd.balanceOf(address(this));
        uint256 rusdBalanceBefore = rusd.balanceOf(address(this));
        yusd.compoundRewards(currentRoundId);
        uint256 yusdBalanceAfter = yusd.balanceOf(address(this));
        uint256 rusdBalanceAfter = rusd.balanceOf(address(this));

        assertEq(rusdBalanceAfter, rusdBalanceBefore);
        assertEq(yusdBalanceAfter, yusdBalanceBefore + claimableRewards);
    }

    function test_RevertIfPaused() public {
        rusdDataHub.pause();
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        yusd.compoundRewards(currentRoundId);
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRound() public test_roundTimestampModifier {
        yusd.compoundRewards(currentRoundId);
    }
}
