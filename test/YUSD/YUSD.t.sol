// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract YUSDTest is YUSDSetup {
    /* ======== upgradeToAndCall ======== */

    function test_upgradeToAndCall_ShouldUpgradeImplementation() public {
        address implementationBefore =
            address(uint160(uint256(vm.load(address(yusd), ERC1967Utils.IMPLEMENTATION_SLOT))));

        address newYUSD = address(new YUSD());
        yusd.upgradeToAndCall(newYUSD, "");

        address implementationAfter =
            address(uint160(uint256(vm.load(address(yusd), ERC1967Utils.IMPLEMENTATION_SLOT))));

        assertNotEq(implementationAfter, implementationBefore);
        assertEq(implementationAfter, newYUSD);
    }

    function test_upgradeToAndCall_RevertIfNotAdmin() public {
        address implementation = address(new YUSD());
        vm.expectRevert(abi.encodeWithSelector(Base.Unauthorized.selector));
        vm.prank(user);
        yusd.upgradeToAndCall(implementation, "");
    }

    /* ======== initialize ======== */

    function test_initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        yusd.initialize(rusdDataHub, 1, 1, 1, 1);
    }

    /* ======== getCurrentRoundId ======== */

    function test_getCurrentRoundId_ShouldReturnCurrentRoundId() public {
        assertEq(yusd.getCurrentRoundId(), 0);
        skip(roundDuration + 1);
        yusd.stake(address(this), 1, mockData);
        assertEq(yusd.getCurrentRoundId(), 1);
    }

    /* ======== getRoundPeriod ======== */

    function test_getRoundPeriod_ShouldReturnRoundPeriod() public {
        (uint32 start0, uint32 end0) = yusd.getRoundPeriod(0);
        assertEq(start0, block.timestamp);
        assertEq(end0, block.timestamp + roundDuration);

        skip(roundDuration + 1);
        yusd.stake(address(this), 1, mockData);

        (uint32 start1, uint32 end1) = yusd.getRoundPeriod(1);

        assertEq(start1, end0);
        assertEq(end1 + 1, block.timestamp + roundDuration);
    }

    /* ======== updateRoundTimestamps ======== */

    function test_updateRoundTimestamps_ShouldUpdateRoundTimestamps() public {
        uint32 roundId0 = currentRoundId;
        uint32 roundId1 = currentRoundId + 1;

        (uint32 bp0, uint32 duration0,) = yusd.getRoundInfo(roundId0);
        (uint32 bp1, uint32 duration1,) = yusd.getRoundInfo(roundId1);

        uint32 roundId1NewDuration = duration0 - 100;
        uint32 roundId1NewBp = bp0 - 100;

        assertNotEq(bp0, 0);
        assertNotEq(duration0, 0);
        assertEq(bp1, 0);
        assertEq(duration1, 0);

        yusd.changeNextRoundDuration(roundId1NewDuration);
        yusd.changeNextRoundBp(roundId1NewBp);

        skip(roundDuration);
        yusd.stake(address(this), MINT_AMOUNT, mockData);

        assertEq(yusd.getCurrentRoundId(), roundId1);

        (, uint32 end0) = yusd.getRoundPeriod(roundId0);
        (uint32 start1, uint32 end1) = yusd.getRoundPeriod(roundId1);

        assertEq(start1, end0);
        assertEq(end1, end0 + roundId1NewDuration);

        (bp1, duration1,) = yusd.getRoundInfo(roundId1);

        assertEq(bp1, roundId1NewBp);
        assertEq(duration1, roundId1NewDuration);
    }

    /* ======== totalDebt ======== */

    function testFuzz_totalDebt_ShouldDecreaseWhenRewardsAreClaimed(uint256 period) public {
        period = bound(period, twabPeriodLength, roundDuration);

        yusd.stake(address(this), MINT_AMOUNT, mockData);

        int256 totalDebtBefore = yusd.totalDebt();
        assertEq(totalDebtBefore, 0);

        skip(period);

        uint256 claimedRewards = yusd.claimRewards(currentRoundId, address(this), address(this));

        int256 totalDebtAfter = yusd.totalDebt();

        assertLt(totalDebtAfter, totalDebtBefore);
        assertEq(totalDebtAfter, -int256(claimedRewards));
    }

    function test_totalDebt_ShouldIncreaseAfterRoundIsFinalized() public {
        yusd.stake(address(this), MINT_AMOUNT, mockData);

        skip(roundDuration);
        yusd.claimRewards(currentRoundId, address(this), address(this));

        assertEq(yusd.totalDebt(), -int256(yusd.calculateTotalRewardsRound(currentRoundId)));

        yusd.finalizeRound(currentRoundId);
        assertEq(yusd.totalDebt(), 0);
    }

    /* ======== decimals ======== */

    function test_decimals_ShouldReturnDecimals() public view {
        assertEq(yusd.decimals(), 6);
    }
}
