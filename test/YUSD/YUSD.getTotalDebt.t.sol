// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract GetTotalDebt is YUSDSetup {
    function test_ShouldReturnTotalDebt() public {
        yusd.stake(address(this), MINT_AMOUNT, mockData);
        skip(roundDuration);
        assertApproxEqAbs(uint256(yusd.getTotalDebt()), _multiplyAmountByBp(MINT_AMOUNT), dust);
    }

    function testFuzz_ShouldIncreaseTotalDebtWithTime(uint256 period) public {
        period = bound(period, twabPeriodLength, roundDuration);

        uint256 totalDebtBefore = uint256(yusd.getTotalDebt());
        assertEq(totalDebtBefore, 0);

        yusd.stake(address(this), MINT_AMOUNT, mockData);

        skip(period);

        uint256 totalDebtAfter = uint256(yusd.getTotalDebt());

        assertGt(totalDebtAfter, totalDebtBefore);

        assertEq(totalDebtAfter, yusd.calculateTotalRewardsRound(yusd.getCurrentRoundId()));
    }

    function test_ShouldReturnNegativeTotalDebtIfUsersClaimedRewardsBeforePeriodEnd() public {
        yusd.stake(address(this), MINT_AMOUNT, mockData);
        skip(roundDuration - 1);
        rusd.mint(address(yusd), MINT_AMOUNT * 100, mockData);
        yusd.claimRewards(yusd.getCurrentRoundId(), address(this), address(this));
        assertLt(yusd.getTotalDebt(), 0);
    }

    function test_ShouldReturnZeroIfNoStaked() public view {
        assertEq(yusd.getTotalDebt(), 0);
    }
}
