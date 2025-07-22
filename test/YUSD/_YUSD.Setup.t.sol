// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "test/BaseSetup.sol";

contract YUSDSetup is BaseSetup {
    uint256 dust = 1 wei; // math errors

    uint32 apr;
    uint32 currentRoundId;
    uint32 roundDuration;

    function _setUp() internal override {
        super._setUp();

        currentRoundId = yusd.getCurrentRoundId();
        roundDuration = yusd.nextRoundDuration();
        apr = yusd.roundApr(currentRoundId);
    }

    function _multiplyAmountByApr(uint256 amount) internal view returns (uint256) {
        return (amount * apr) / yusd.APR_PRECISION();
    }

    function _endCurrentTwabObservationPeriod() internal {
        skip(twabPeriodLength);
    }

    modifier test_roundTimestampModifier() {
        yusd.mint(address(this), 1, "");

        (, uint32 end) = yusd.getRoundPeriod(currentRoundId);
        vm.warp(end + 1);

        vm.expectEmit(true, true, true, true);
        emit IYUSD.NewRound(currentRoundId + 1, end, end + yusd.nextRoundDuration());
        _;

        uint32 _currentRoundId = yusd.getCurrentRoundId();
        (uint32 _start, uint32 _end) = yusd.getRoundPeriod(_currentRoundId);

        assertEq(_currentRoundId, currentRoundId + 1);
        assertEq(_start, end);
        assertEq(_end, end + yusd.nextRoundDuration());
    }
}
