// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract CalculateClaimableRewards is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(yusd), MINT_AMOUNT * 100, "");

        yusd.mint(address(this), MINT_AMOUNT, "");
        skip(roundDuration + 1);
    }

    function test_ShouldReturnZeroIfNoRewards() public view {
        assertEq(yusd.calculateClaimableRewards(currentRoundId, user), 0);
    }

    function test_ShouldReturnAllRewardsIfRewardsWasNotClaimed() public view {
        uint256 targetRewards = _multiplyAmountByApr(MINT_AMOUNT);

        uint256 claimableRewards = yusd.calculateClaimableRewards(currentRoundId, address(this));

        assertApproxEqAbs(claimableRewards, targetRewards, dust);
    }

    function testFuzz_ShouldReturnLessRewardsIfRewardsWasClaimed(uint256 amount) public {
        uint256 claimableRewards = yusd.calculateClaimableRewards(currentRoundId, address(this));

        amount = bound(amount, 1, claimableRewards);

        yusd.claimRewards(currentRoundId, amount, address(this));

        assertEq(
            yusd.calculateClaimableRewards(currentRoundId, address(this)), claimableRewards - amount
        );
    }
}
