// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.0;

import {RingBufferLib} from "./RingBufferLib.sol";

/**
 * @dev Sets max ring buffer cardinality in the Account.observations Observation list.
 *         As users transfer/mint/burn tickets new Observation checkpoints are recorded.
 *         The current `MAX_CARDINALITY` guarantees a one year minimum, of accurate historical lookups.
 * @dev The user Account.Account.cardinality parameter can NOT exceed the max cardinality variable.
 *      Preventing "corrupted" ring buffer lookup pointers and new observation checkpoints.
 */
uint16 constant MAX_CARDINALITY = 17520; // with min period of 1 hour, this allows for minimum two years of history

library ObservationLib {
    /**
     * @notice Observation, which includes an amount and timestamp.
     * @param cumulativeBalance the cumulative time-weighted balance at `timestamp`.
     * @param balance `balance` at `timestamp`.
     * @param timestamp Recorded `timestamp`.
     */
    struct Observation {
        uint128 cumulativeBalance;
        uint96 balance;
        uint32 timestamp;
    }

    /**
     * @notice Fetches Observations `beforeOrAt` and `afterOrAt` a `_target`, eg: where [`beforeOrAt`, `afterOrAt`] is satisfied.
     * The result may be the same Observation, or adjacent Observations.
     * @dev The _target must fall within the boundaries of the provided _observations.
     * Meaning the _target must be: older than the most recent Observation and younger, or the same age as, the oldest Observation.
     * @dev  If `_newestObservationIndex` is less than `_oldestObservationIndex`, it means that we've wrapped around the ring buffer.
     *       So the most recent observation will be at `_oldestObservationIndex + _cardinality - 1`, at the beginning of the ring buffer.
     * @param _observations List of Observations to search through.
     * @param _newestObservationIndex Index of the newest Observation. Right side of the ring buffer.
     * @param _oldestObservationIndex Index of the oldest Observation. Left side of the ring buffer.
     * @param _target Timestamp at which we are searching the Observation.
     * @param _cardinality Cardinality of the ring buffer we are searching through.
     * @return beforeOrAt Observation recorded before, or at, the target.
     * @return beforeOrAtIndex Index of observation recorded before, or at, the target.
     * @return afterOrAt Observation recorded at, or after, the target.
     * @return afterOrAtIndex Index of observation recorded at, or after, the target.
     */
    function binarySearch(
        Observation[MAX_CARDINALITY] storage _observations,
        uint24 _newestObservationIndex,
        uint24 _oldestObservationIndex,
        uint32 _target,
        uint16 _cardinality
    )
        internal
        view
        returns (
            Observation memory beforeOrAt,
            uint16 beforeOrAtIndex,
            Observation memory afterOrAt,
            uint16 afterOrAtIndex
        )
    {
        if (
            _oldestObservationIndex >= MAX_CARDINALITY || _newestObservationIndex >= MAX_CARDINALITY
        ) revert IndexOutOfBounds();

        uint256 leftSide = _oldestObservationIndex;
        uint256 rightSide = _newestObservationIndex < leftSide
            ? _newestObservationIndex + _cardinality
            : _newestObservationIndex;
        uint256 currentIndex;

        while (true) {
            // If the search pointers have crossed, it means the target is not within the range.
            // This prevents an infinite loop.
            // This case should ideally not be reached if the calling contract performs checks,
            // but as a safety measure, we revert to prevent a gas-consuming infinite loop.
            if (leftSide > rightSide) revert TargetNotFoundInObservations();

            // We start our search in the middle of the `leftSide` and `rightSide`.
            // After each iteration, we narrow down the search to the left or the right side while still starting our search in the middle.
            currentIndex = (leftSide + rightSide) / 2;

            beforeOrAtIndex = uint16(RingBufferLib.wrap(currentIndex, _cardinality));
            beforeOrAt = _observations[beforeOrAtIndex];
            uint32 beforeOrAtTimestamp = beforeOrAt.timestamp;

            // Check if we are at the newest observation.
            // If so, there is no "after" observation, so we treat the newest one as both 'before' and 'after'.
            if (beforeOrAtIndex == _newestObservationIndex) {
                afterOrAtIndex = beforeOrAtIndex;
                afterOrAt = beforeOrAt;
            } else {
                afterOrAtIndex = uint16(RingBufferLib.nextIndex(currentIndex, _cardinality));
                afterOrAt = _observations[afterOrAtIndex];
            }

            bool targetAfterOrAt = beforeOrAtTimestamp <= _target;

            // Check if we've found the corresponding Observation.
            if (targetAfterOrAt && _target <= afterOrAt.timestamp) {
                // If either observation is an exact match, collapse the interval to that point
                // to make the function's behavior unambiguous.
                if (afterOrAt.timestamp == _target) {
                    beforeOrAt = afterOrAt;
                    beforeOrAtIndex = afterOrAtIndex;
                } else if (beforeOrAtTimestamp == _target) {
                    afterOrAt = beforeOrAt;
                    afterOrAtIndex = beforeOrAtIndex;
                }
                break;
            }

            // If `beforeOrAtTimestamp` is greater than `_target`, then we keep searching lower. To the left of the current index.
            if (!targetAfterOrAt) rightSide = currentIndex - 1;
            // Otherwise, we keep searching higher. To the right of the current index.
            else leftSide = currentIndex + 1;
        }
    }

    error TargetNotFoundInObservations();
    error IndexOutOfBounds();
}
