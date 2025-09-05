// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract ClaimRewards is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(yusd), MINT_AMOUNT * 100, mockData);

        yusd.stake(address(this), MINT_AMOUNT, mockData);
        (, uint32 end) = yusd.getRoundPeriod(currentRoundId);
        vm.warp(end);
        _finalizeCurrentRound();
    }

    function test_ShouldClaimAllRewardsForRound() public {
        uint256 targetRewards = _multiplyAmountByBp(MINT_AMOUNT);

        uint256 balanceBefore = rusd.balanceOf(address(this));
        uint256 rewards = yusd.claimRewards(currentRoundId, address(this), address(this));
        uint256 balanceAfter = rusd.balanceOf(address(this));

        assertApproxEqAbs(rewards, targetRewards, dust);
        assertEq(balanceAfter, balanceBefore + rewards);
    }

    function testFuzz_ShouldClaimRewardsForRoundWhenAmountSpecified(uint256 amount) public {
        amount = bound(amount, 1, yusd.calculateClaimableRewards(currentRoundId, address(this)));

        uint256 balanceBefore = rusd.balanceOf(address(this));
        yusd.claimRewards(currentRoundId, address(this), address(this), amount);
        uint256 balanceAfter = rusd.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_RevertIfClaimingMoreThanAvailableRewards() public {
        uint256 targetRewards = _multiplyAmountByBp(MINT_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                IYUSD.InsufficientRewards.selector,
                targetRewards + 1,
                yusd.calculateClaimableRewards(currentRoundId, address(this))
            )
        );
        yusd.claimRewards(currentRoundId, address(this), address(this), targetRewards + 1);
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(Base.ZeroAmount.selector));
        yusd.claimRewards(currentRoundId, address(this), address(this), 0);
    }

    function test_RevertIfHighPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        yusd.claimRewards(currentRoundId, address(this), address(this));
    }

    function test_RevertIfHighPausedWhenAmountSpecified() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        yusd.claimRewards(currentRoundId, address(this), address(this), 1);
    }

    function test_RevertIfNotMinter() public {
        vm.expectRevert(Base.Unauthorized.selector);
        vm.prank(user);
        yusd.claimRewards(currentRoundId, address(this), address(this));
    }

    function test_RevertIfNotMinterWhenAmountSpecified() public {
        vm.expectRevert(Base.Unauthorized.selector);
        vm.prank(user);
        yusd.claimRewards(currentRoundId, address(this), address(this), 1);
    }

    function test_ShouldEmitEvent() public {
        uint256 rewards = yusd.calculateClaimableRewards(currentRoundId, address(this));

        vm.expectEmit(true, true, true, true);
        emit IYUSD.RewardsClaimed(currentRoundId, address(this), address(this), rewards);
        yusd.claimRewards(currentRoundId, address(this), address(this));
    }

    function test_ShouldEmitEventWhenAmountSpecified() public {
        vm.expectEmit(true, true, true, true);
        emit IYUSD.RewardsClaimed(currentRoundId, address(this), address(this), 1);
        yusd.claimRewards(currentRoundId, address(this), address(this), 1);
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRoundA() public test_roundTimestampModifier {
        yusd.claimRewards(currentRoundId, address(this), address(this));
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRoundB() public test_roundTimestampModifier {
        yusd.claimRewards(currentRoundId, address(this), address(this), 1);
    }
}
