// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract CalculateTotalRewardsRound is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(this), MINT_AMOUNT, mockData);
    }

    function test_ShouldReturnZeroIfNoRewards() public view {
        assertEq(yusd.totalSupply(), 0);
        assertEq(yusd.calculateTotalRewardsRound(currentRoundId), 0);
    }

    function test_ShouldReturnTotalRewards() public {
        yusd.stake(address(this), MINT_AMOUNT, mockData);

        skip(roundDuration);

        assertApproxEqAbs(
            yusd.calculateTotalRewardsRound(currentRoundId),
            yusd.calculateClaimableRewards(currentRoundId, address(this)),
            dust
        );
    }
}
