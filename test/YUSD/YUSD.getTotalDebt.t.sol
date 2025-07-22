// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract GetTotalDebt is YUSDSetup {
    function test_ShouldReturnTotalDebt() public {
        yusd.mint(address(this), MINT_AMOUNT, "");
        skip(roundDuration + 1);
        assertApproxEqAbs(yusd.getTotalDebt(), _multiplyAmountByApr(MINT_AMOUNT), dust);
    }

    function testFuzz_ShouldIncreaseTotalDebtWithTime(uint256 period) public {
        period = bound(period, twabPeriodLength, roundDuration);

        uint256 totalDebtBefore = yusd.getTotalDebt();
        assertEq(totalDebtBefore, 0);

        yusd.mint(address(this), MINT_AMOUNT, "");

        skip(period);

        uint256 totalDebtAfter = yusd.getTotalDebt();

        assertGt(totalDebtAfter, totalDebtBefore);

        // TODO: calculate the correct value
        // assertApproxEqAbs(
        //     totalDebtAfter, _multiplyAmountByApr(MINT_AMOUNT) * period / roundDuration, dust
        // );
    }

    function test_ShouldReturnZeroIfNoStaked() public view {
        assertEq(yusd.getTotalDebt(), 0);
    }
}
