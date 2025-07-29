// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract CalculateRewardsRound is YUSDSetup {
    uint32 start;
    uint32 middle;
    uint32 end;

    function _afterSetUp() internal override {
        rusd.mint(address(yusd), MINT_AMOUNT * 100, mockData);

        yusd.stake(address(this), MINT_AMOUNT, mockData);

        rusd.mint(address(this), MINT_AMOUNT, mockData);
        yusd.stake(user, MINT_AMOUNT, mockData);

        (start, end) = yusd.getRoundPeriod(currentRoundId);
        middle = start + (end - start) / 2;
    }

    function testFuzz_ShouldIncreaseRewardsWithTime(uint256 period) public {
        period = bound(period, twabPeriodLength, end - start);

        skip(period);

        assertGt(yusd.calculateRewardsRound(currentRoundId, address(this)), 0);
    }

    function test_ShouldYieldHalfOfRewardsForPeriodByTheMiddle() public {
        vm.warp(middle);

        uint256 generatedRewards = yusd.calculateRewardsRound(currentRoundId, address(this));
        uint256 targetRewards = _multiplyAmountByBp(MINT_AMOUNT) / 2;

        assertApproxEqAbs(generatedRewards, targetRewards, dust);
    }

    function test_ShouldYieldAllRewardsForPeriodByTheEnd() public {
        vm.warp(end);

        uint256 generatedRewards = yusd.calculateRewardsRound(currentRoundId, address(this));
        uint256 targetRewards = _multiplyAmountByBp(MINT_AMOUNT);

        assertApproxEqAbs(generatedRewards, targetRewards, dust);
    }

    function test_ShouldYieldCorrectRewardsWhenClaimingRewardsInNotEndedRound() public {
        vm.warp(middle);

        uint256 generatedRewardsByThisBefore =
            yusd.calculateRewardsRound(currentRoundId, address(this));
        uint256 generatedRewardsByUserBefore = yusd.calculateRewardsRound(currentRoundId, user);

        assertEq(generatedRewardsByThisBefore, generatedRewardsByUserBefore);

        yusd.redeem(address(this), MINT_AMOUNT, mockData);

        vm.warp(end);

        uint256 generatedRewardsByThisAfter =
            yusd.calculateRewardsRound(currentRoundId, address(this));
        uint256 generatedRewardsByUserAfter = yusd.calculateRewardsRound(currentRoundId, user);

        assertApproxEqAbs(generatedRewardsByThisAfter, generatedRewardsByThisBefore, dust);
        assertApproxEqAbs(generatedRewardsByThisAfter, generatedRewardsByUserBefore, dust);
        assertApproxEqAbs(generatedRewardsByUserAfter, generatedRewardsByUserBefore * 2, dust);
    }

    function test_ShouldYieldHalfOfRewardsByTheMiddleAndNoMore() public {
        vm.warp(middle);

        yusd.redeem(address(this), MINT_AMOUNT, mockData);
        uint256 generatedRewardsBefore = yusd.calculateRewardsRound(currentRoundId, address(this));

        vm.warp(end);

        uint256 generatedRewardsAfter = yusd.calculateRewardsRound(currentRoundId, address(this));
        uint256 targetRewards = _multiplyAmountByBp(MINT_AMOUNT) / 2;

        assertApproxEqAbs(generatedRewardsAfter, targetRewards, dust);
        assertApproxEqAbs(generatedRewardsAfter, generatedRewardsBefore, dust);
    }

    function test_TwoStakersShouldYieldDifferentRewardsWhenStakingDifferentPeriods() public {
        vm.warp(middle);

        uint256 rewardsBeforeUser = yusd.calculateRewardsRound(currentRoundId, user);
        uint256 rewardsBeforeThis = yusd.calculateRewardsRound(currentRoundId, address(this));
        assertEq(rewardsBeforeUser, rewardsBeforeThis);

        yusd.redeem(address(this), MINT_AMOUNT, mockData);

        vm.warp(end);

        uint256 rewardsAfterUser = yusd.calculateRewardsRound(currentRoundId, user);
        uint256 rewardsAfterThis = yusd.calculateRewardsRound(currentRoundId, address(this));

        assertApproxEqAbs(rewardsAfterUser, rewardsAfterThis * 2, dust);
        assertApproxEqAbs(rewardsAfterThis, rewardsBeforeThis, dust);
    }

    function test_ShouldYieldAllRewardsByTheEndAndNoMore() public {
        vm.warp(end);

        uint256 generatedRewardsBefore = yusd.calculateRewardsRound(currentRoundId, address(this));
        vm.warp(end + 1e6);
        uint256 generatedRewardsAfter = yusd.calculateRewardsRound(currentRoundId, address(this));

        assertEq(generatedRewardsAfter, generatedRewardsBefore);
    }

    function test_AuditorScenario_ShouldNotOverpayUser() public {
        // SETUP: Attacker gets YUSD at the start of the round.
        // We will use `address(this)` as the attacker for simplicity.
        address attacker = address(this);
        rusd.mint(attacker, MINT_AMOUNT * 100, mockData);

        // Make sure only the attacker has tokens to isolate the test case.
        yusd.redeem(user, uint96(yusd.balanceOf(user)), mockData);
        assertEq(yusd.balanceOf(attacker), MINT_AMOUNT);

        // ATTACK PART 1: Claim rewards in the middle of the round.
        vm.warp(middle);

        uint256 rusdBalanceBefore = rusd.balanceOf(attacker);

        // Attacker claims rewards for the current, active round.
        uint256 claimedAmount = yusd.claimRewards(currentRoundId, attacker, attacker);

        assertEq(
            rusd.balanceOf(attacker) - rusdBalanceBefore, claimedAmount, "RUSD was not transferred"
        );
        assertGt(claimedAmount, 0, "No rewards were claimed in the middle of the round");

        // ATTACK PART 2: Attacker burns all their YUSD immediately after.
        yusd.redeem(attacker, MINT_AMOUNT, mockData);
        assertEq(yusd.balanceOf(attacker), 0);

        // VERIFICATION
        vm.warp(end);

        // 1. Check that the claimed amount is the correct total reward for the entire round.
        // The attacker held MINT_AMOUNT for half the round, so their average balance
        // for the *entire* round results in half the rewards.
        uint256 totalCorrectRewards = _multiplyAmountByBp(MINT_AMOUNT) / 2;
        assertApproxEqAbs(claimedAmount, totalCorrectRewards, dust, "Claimed amount is incorrect");

        // 2. Check that the attacker cannot claim any more rewards at the end of the round.
        uint256 remainingClaimable = yusd.calculateClaimableRewards(currentRoundId, attacker);
        assertEq(remainingClaimable, 0, "Attacker can still claim more rewards at the end");

        // 3. Double check by actually trying to claim again.
        rusdBalanceBefore = rusd.balanceOf(attacker);
        vm.expectRevert(abi.encodeWithSelector(Base.ZeroAmount.selector));
        yusd.claimRewards(currentRoundId, attacker, attacker);
    }
}
