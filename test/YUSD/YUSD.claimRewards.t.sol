// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract ClaimRewards is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(yusd), MINT_AMOUNT * 100, "");

        yusd.mint(address(this), MINT_AMOUNT, "");
        (, uint32 end) = yusd.getRoundPeriod(currentRoundId);
        vm.warp(end);
    }

    function test_ShouldClaimAllRewardsForRound() public {
        uint256 targetRewards = _multiplyAmountByApr(MINT_AMOUNT);

        uint256 balanceBefore = rusd.balanceOf(address(this));
        uint256 rewards = yusd.claimRewards(currentRoundId, address(this));
        uint256 balanceAfter = rusd.balanceOf(address(this));

        assertApproxEqAbs(rewards, targetRewards, dust);
        assertEq(balanceAfter, balanceBefore + rewards);
    }

    function testFuzz_ShouldClaimRewardsForRoundWhenAmountSpecified(uint256 amount) public {
        amount = bound(amount, 1, yusd.calculateClaimableRewards(currentRoundId, address(this)));

        uint256 balanceBefore = rusd.balanceOf(address(this));
        yusd.claimRewards(currentRoundId, amount, address(this));
        uint256 balanceAfter = rusd.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_RevertIfClaimingMoreThanAvailableRewards() public {
        uint256 targetRewards = _multiplyAmountByApr(MINT_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                IYUSD.InsufficientRewards.selector,
                targetRewards + 1,
                yusd.calculateClaimableRewards(currentRoundId, address(this))
            )
        );
        yusd.claimRewards(currentRoundId, targetRewards + 1, address(this));
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(Base.ZeroAmount.selector));
        yusd.claimRewards(currentRoundId, 0, address(this));
    }

    function test_RevertIfPaused() public {
        rusdDataHub.pause();
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        yusd.claimRewards(currentRoundId, 1, address(this));
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        yusd.claimRewards(currentRoundId, address(this));
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRoundA() public test_roundTimestampModifier {
        yusd.claimRewards(currentRoundId, address(this));
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRoundB() public test_roundTimestampModifier {
        yusd.claimRewards(currentRoundId, 1, address(this));
    }
}
