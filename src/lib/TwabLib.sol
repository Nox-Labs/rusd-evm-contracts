// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {RingBufferLib} from "./RingBufferLib.sol";

import {ObservationLib, MAX_CARDINALITY} from "./ObservationLib.sol";

library TwabLib {
    type PeriodOffsetRelativeTimestamp is uint32;

    /// @notice Emitted when a balance is decreased by an amount that exceeds the amount available.
    /// @param balance The current balance of the account
    /// @param amount The amount being decreased from the account's balance
    /// @param message An additional message describing the error
    error BalanceLTAmount(uint96 balance, uint96 amount, string message);

    /// @notice Emitted when a delegate balance is decreased by an amount that exceeds the amount available.
    /// @param delegateBalance The current delegate balance of the account
    /// @param delegateAmount The amount being decreased from the account's delegate balance
    /// @param message An additional message describing the error
    error DelegateBalanceLTAmount(uint96 delegateBalance, uint96 delegateAmount, string message);

    /// @notice Emitted when a request is made for a twab that is not yet finalized.
    /// @param timestamp The requested timestamp
    /// @param currentOverwritePeriodStartedAt The current overwrite period start time
    error TimestampNotFinalized(uint256 timestamp, uint256 currentOverwritePeriodStartedAt);

    /// @notice Emitted when a TWAB time range start is after the end.
    /// @param start The start time
    /// @param end The end time
    error InvalidTimeRange(uint256 start, uint256 end);

    /// @notice Emitted when there is insufficient history to lookup a twab time range
    /// @param requestedTimestamp The timestamp requested
    /// @param oldestTimestamp The oldest timestamp that can be read
    error InsufficientHistory(
        PeriodOffsetRelativeTimestamp requestedTimestamp,
        PeriodOffsetRelativeTimestamp oldestTimestamp
    );

    /**
     * @notice Struct ring buffer parameters for single user Account.
     * @param balance Current token balance for an Account
     * @param nextObservationIndex Next uninitialized or updatable ring buffer checkpoint storage slot
     * @param bufferCount Current total "initialized" ring buffer checkpoints for single user Account.
     *                    Used to set initial boundary conditions for an efficient binary search.
     */
    struct AccountDetails {
        uint96 balance;
        uint16 nextObservationIndex;
        uint16 bufferCount;
    }

    /**
     * @notice Account details and historical twabs.
     * @dev The size of observations is MAX_CARDINALITY from the ObservationLib.
     * @param details The account details
     * @param observations The history of observations for this account
     */
    struct Account {
        AccountDetails details;
        ObservationLib.Observation[MAX_CARDINALITY] observations;
    }

    /**
     * @notice Increase a user's balance and delegate balance by a given amount.
     * @dev This function mutates the provided account.
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @param _account The account to update
     * @param _amount The amount to increase the balance by
     * @return observation The new/updated observation
     * @return isNew Whether or not the observation is new or overwrote a previous one
     * @return isObservationRecorded Whether or not an observation was recorded to storage
     */
    function increaseBalances(
        uint32 periodLength,
        uint32 periodOffset,
        Account storage _account,
        uint96 _amount
    )
        internal
        returns (
            ObservationLib.Observation memory observation,
            bool isNew,
            bool isObservationRecorded,
            AccountDetails memory accountDetails
        )
    {
        accountDetails = _account.details;
        // Only record an observation if the current timestamp is within the valid range.
        isObservationRecorded =
            block.timestamp <= maxRecordableTimestamp(periodLength, periodOffset);

        accountDetails.balance += _amount;

        // Only record a new Observation if the users delegateBalance has changed.
        if (isObservationRecorded) {
            (observation, isNew, accountDetails) =
                _recordObservation(periodLength, periodOffset, accountDetails, _account);
        }

        _account.details = accountDetails;
    }

    /**
     * @notice Decrease a user's balance and delegate balance by a given amount.
     * @dev This function mutates the provided account.
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @param _account The account to update
     * @param _amount The amount to decrease the balance by
     * @param _revertMessage The revert message to use if the balance is insufficient
     * @return observation The new/updated observation
     * @return isNew Whether or not the observation is new or overwrote a previous one
     * @return isObservationRecorded Whether or not the observation was recorded to storage
     */
    function decreaseBalances(
        uint32 periodLength,
        uint32 periodOffset,
        Account storage _account,
        uint96 _amount,
        string memory _revertMessage
    )
        internal
        returns (
            ObservationLib.Observation memory observation,
            bool isNew,
            bool isObservationRecorded,
            AccountDetails memory accountDetails
        )
    {
        accountDetails = _account.details;

        if (accountDetails.balance < _amount) {
            revert BalanceLTAmount(accountDetails.balance, _amount, _revertMessage);
        }

        // Only record an observation if the current timestamp is within the valid range.
        isObservationRecorded =
            block.timestamp <= maxRecordableTimestamp(periodLength, periodOffset);

        accountDetails.balance -= _amount;

        // Only record a new Observation if the users delegateBalance has changed.
        if (isObservationRecorded) {
            (observation, isNew, accountDetails) =
                _recordObservation(periodLength, periodOffset, accountDetails, _account);
        }

        _account.details = accountDetails;
    }

    /**
     * @notice Looks up the oldest observation in the ring buffer.
     * @param _observations The ring buffer of observations
     * @param _accountDetails The account details to query with
     * @return index The index of the oldest observation
     * @return observation The oldest observation in the ring buffer
     */
    function getOldestObservation(
        ObservationLib.Observation[MAX_CARDINALITY] storage _observations,
        AccountDetails memory _accountDetails
    ) internal view returns (uint16 index, ObservationLib.Observation memory observation) {
        // If the ring buffer has not been fully populated, we go to the beginning of the buffer at index 0.
        if (_accountDetails.bufferCount < MAX_CARDINALITY) {
            index = 0;
            observation = _observations[0];
        } else {
            index = _accountDetails.nextObservationIndex;
            observation = _observations[index];
        }
    }

    /**
     * @notice Looks up the newest observation in the ring buffer.
     * @param _observations The ring buffer of observations
     * @param _accountDetails The account details to query with
     * @return index The index of the newest observation
     * @return observation The newest observation in the ring buffer
     */
    function getNewestObservation(
        ObservationLib.Observation[MAX_CARDINALITY] storage _observations,
        AccountDetails memory _accountDetails
    ) internal view returns (uint16 index, ObservationLib.Observation memory observation) {
        index =
            uint16(RingBufferLib.newestIndex(_accountDetails.nextObservationIndex, MAX_CARDINALITY));
        observation = _observations[index];
    }

    /**
     * @notice Looks up a users balance at a specific time in the past. The time must be before the current overwrite period.
     * @dev Ensure timestamps are safe using requireFinalized
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @param _observations The ring buffer of observations
     * @param _accountDetails The account details to query with
     * @param _targetTime The time to look up the balance at
     * @return balance The balance at the target time
     */
    function getBalanceAt(
        uint32 periodLength,
        uint32 periodOffset,
        ObservationLib.Observation[MAX_CARDINALITY] storage _observations,
        AccountDetails memory _accountDetails,
        uint256 _targetTime
    ) internal view requireFinalized(periodLength, periodOffset, _targetTime) returns (uint256) {
        if (_targetTime < periodOffset) {
            return 0;
        }
        // if this is for an overflowed time period, return 0
        if (isShutdownAt(_targetTime, periodLength, periodOffset)) {
            return 0;
        }
        ObservationLib.Observation memory prevOrAtObservation = _getPreviousOrAtObservation(
            _observations,
            _accountDetails,
            PeriodOffsetRelativeTimestamp.wrap(uint32(_targetTime - periodOffset))
        );
        return prevOrAtObservation.balance;
    }

    /**
     * @notice Returns whether the TwabController has been shutdown at the given timestamp
     * If the twab is queried at or after this time, whether an absolute timestamp or time range, it will return 0.
     * @param timestamp The timestamp to check
     * @param periodOffset The offset of the first period
     * @return True if the TwabController is shutdown at the given timestamp, false otherwise.
     */
    function isShutdownAt(uint256 timestamp, uint32 periodLength, uint32 periodOffset)
        internal
        pure
        returns (bool)
    {
        return timestamp > maxRecordableTimestamp(periodLength, periodOffset);
    }

    /**
     * @notice Computes the largest timestamp at which the TwabController can record a new observation.
     * @param periodOffset The offset of the first period
     * @return The largest timestamp at which the TwabController can record a new observation.
     */
    function maxRecordableTimestamp(uint32 periodLength, uint32 periodOffset)
        internal
        pure
        returns (uint256)
    {
        return uint256(periodOffset) + (type(uint32).max / periodLength) * periodLength;
    }

    /**
     * @notice Looks up a users TWAB for a time range. The time must be before the current overwrite period.
     * @dev If the timestamps in the range are not exact matches of observations, the balance is extrapolated using the previous observation.
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @param _observations The ring buffer of observations
     * @param _accountDetails The account details to query with
     * @param _startTime The start of the time range
     * @param _endTime The end of the time range
     * @return twab The TWAB for the time range
     */
    function getTwabBetween(
        uint32 periodLength,
        uint32 periodOffset,
        ObservationLib.Observation[MAX_CARDINALITY] storage _observations,
        AccountDetails memory _accountDetails,
        uint256 _startTime,
        uint256 _endTime
    ) internal view requireFinalized(periodLength, periodOffset, _endTime) returns (uint256) {
        if (_endTime < _startTime) {
            revert InvalidTimeRange(_startTime, _endTime);
        }

        // if the range extends into the shutdown period, return 0
        if (isShutdownAt(_endTime, periodLength, periodOffset)) {
            return 0;
        }

        uint256 offsetStartTime = _startTime - periodOffset;
        uint256 offsetEndTime = _endTime - periodOffset;

        ObservationLib.Observation memory endObservation = _getPreviousOrAtObservation(
            _observations,
            _accountDetails,
            PeriodOffsetRelativeTimestamp.wrap(uint32(offsetEndTime))
        );

        if (offsetStartTime == offsetEndTime) {
            return endObservation.balance;
        }

        ObservationLib.Observation memory startObservation = _getPreviousOrAtObservation(
            _observations,
            _accountDetails,
            PeriodOffsetRelativeTimestamp.wrap(uint32(offsetStartTime))
        );

        if (startObservation.timestamp != offsetStartTime) {
            startObservation = _calculateTemporaryObservation(
                startObservation, PeriodOffsetRelativeTimestamp.wrap(uint32(offsetStartTime))
            );
        }

        if (endObservation.timestamp != offsetEndTime) {
            endObservation = _calculateTemporaryObservation(
                endObservation, PeriodOffsetRelativeTimestamp.wrap(uint32(offsetEndTime))
            );
        }

        // Difference in amount / time
        return (endObservation.cumulativeBalance - startObservation.cumulativeBalance)
            / (offsetEndTime - offsetStartTime);
    }

    /**
     * @notice Given an AccountDetails with updated balances, either updates the latest Observation or records a new one
     * @param periodLength The overwrite period length
     * @param periodOffset The overwrite period offset
     * @param _accountDetails The updated account details
     * @param _account The account to update
     * @return observation The new/updated observation
     * @return isNew Whether or not the observation is new or overwrote a previous one
     * @return newAccountDetails The new account details
     */
    function _recordObservation(
        uint32 periodLength,
        uint32 periodOffset,
        AccountDetails memory _accountDetails,
        Account storage _account
    )
        internal
        returns (
            ObservationLib.Observation memory observation,
            bool isNew,
            AccountDetails memory newAccountDetails
        )
    {
        PeriodOffsetRelativeTimestamp currentTime =
            PeriodOffsetRelativeTimestamp.wrap(uint32(block.timestamp - periodOffset));

        uint16 nextIndex;
        ObservationLib.Observation memory newestObservation;
        (nextIndex, newestObservation, isNew) = _getNextObservationIndex(
            periodLength, periodOffset, _account.observations, _accountDetails
        );

        if (isNew) {
            // If the index is new, then we increase the next index to use
            _accountDetails.nextObservationIndex =
                uint16(RingBufferLib.nextIndex(uint256(nextIndex), MAX_CARDINALITY));

            // Prevent the Account specific bufferCount from exceeding the MAX_CARDINALITY.
            // The ring buffer length is limited by MAX_CARDINALITY. IF the account.bufferCount
            // exceeds the max bufferCount, new observations would be incorrectly set or the
            // observation would be out of "bounds" of the ring buffer. Once reached the
            // Account.bufferCount will continue to be equal to max bufferCount.
            _accountDetails.bufferCount = _accountDetails.bufferCount < MAX_CARDINALITY
                ? _accountDetails.bufferCount + 1
                : MAX_CARDINALITY;
        }

        observation = ObservationLib.Observation({
            cumulativeBalance: _extrapolateFromBalance(newestObservation, currentTime),
            balance: _accountDetails.balance,
            timestamp: PeriodOffsetRelativeTimestamp.unwrap(currentTime)
        });

        // Write to storage
        _account.observations[nextIndex] = observation;
        newAccountDetails = _accountDetails;
    }

    /**
     * @notice Calculates a temporary observation for a given time using the previous observation.
     * @dev This is used to extrapolate a balance for any given time.
     * @param _observation The previous observation
     * @param _time The time to extrapolate to
     */
    function _calculateTemporaryObservation(
        ObservationLib.Observation memory _observation,
        PeriodOffsetRelativeTimestamp _time
    ) private pure returns (ObservationLib.Observation memory) {
        return ObservationLib.Observation({
            cumulativeBalance: _extrapolateFromBalance(_observation, _time),
            balance: _observation.balance,
            timestamp: PeriodOffsetRelativeTimestamp.unwrap(_time)
        });
    }

    /**
     * @notice Looks up the next observation index to write to in the ring buffer.
     * @dev If the current time is in the same period as the newest observation, we overwrite it.
     * @dev If the current time is in a new period, we increment the index and write a new observation.
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @param _observations The ring buffer of observations
     * @param _accountDetails The account details to query with
     * @return index The index of the next observation slot to overwrite
     * @return newestObservation The newest observation in the ring buffer
     * @return isNew True if the observation slot is new, false if we're overwriting
     */
    function _getNextObservationIndex(
        uint32 periodLength,
        uint32 periodOffset,
        ObservationLib.Observation[MAX_CARDINALITY] storage _observations,
        AccountDetails memory _accountDetails
    )
        private
        view
        returns (uint16 index, ObservationLib.Observation memory newestObservation, bool isNew)
    {
        uint16 newestIndex;
        (newestIndex, newestObservation) = getNewestObservation(_observations, _accountDetails);

        uint256 currentPeriod = getTimestampPeriod(periodLength, periodOffset, block.timestamp);

        uint256 newestObservationPeriod = getTimestampPeriod(
            periodLength, periodOffset, periodOffset + uint256(newestObservation.timestamp)
        );

        // Create a new Observation if it's the first period or the current time falls within a new period
        if (_accountDetails.bufferCount == 0 || currentPeriod > newestObservationPeriod) {
            return (_accountDetails.nextObservationIndex, newestObservation, true);
        }

        // Otherwise, we're overwriting the current newest Observation
        return (newestIndex, newestObservation, false);
    }

    /**
     * @notice Computes the start time of the current overwrite period
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @return The start time of the current overwrite period
     */
    function _currentOverwritePeriodStartedAt(uint32 periodLength, uint32 periodOffset)
        private
        view
        returns (uint256)
    {
        uint256 period = getTimestampPeriod(periodLength, periodOffset, block.timestamp);
        return getPeriodStartTime(periodLength, periodOffset, period);
    }

    /**
     * @notice Calculates the next cumulative balance using a provided Observation and timestamp.
     * @param _observation The observation to extrapolate from
     * @param _offsetTimestamp The timestamp to extrapolate to
     * @return cumulativeBalance The cumulative balance at the timestamp
     */
    function _extrapolateFromBalance(
        ObservationLib.Observation memory _observation,
        PeriodOffsetRelativeTimestamp _offsetTimestamp
    ) private pure returns (uint128) {
        // new cumulative balance = provided cumulative balance (or zero) + (current balance * elapsed seconds)
        unchecked {
            return uint128(
                uint256(_observation.cumulativeBalance)
                    + uint256(_observation.balance)
                        * (PeriodOffsetRelativeTimestamp.unwrap(_offsetTimestamp) - _observation.timestamp)
            );
        }
    }

    /**
     * @notice Computes the overwrite period start time given the current time
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @return The start time for the current overwrite period.
     */
    function currentOverwritePeriodStartedAt(uint32 periodLength, uint32 periodOffset)
        internal
        view
        returns (uint256)
    {
        return _currentOverwritePeriodStartedAt(periodLength, periodOffset);
    }

    /**
     * @notice Calculates the period a timestamp falls within.
     * @dev Timestamp prior to the periodOffset are considered to be in period 0.
     * @param periodLength The length of an overwrite period
     * @param periodOffset The offset of the first period
     * @param _timestamp The timestamp to calculate the period for
     * @return period The period
     */
    function getTimestampPeriod(uint32 periodLength, uint32 periodOffset, uint256 _timestamp)
        internal
        pure
        returns (uint256)
    {
        if (_timestamp <= periodOffset) {
            return 0;
        }
        return (_timestamp - periodOffset) / uint256(periodLength);
    }

    /**
     * @notice Calculates the start timestamp for a period
     * @param periodLength The period length to use to calculate the period
     * @param periodOffset The period offset to use to calculate the period
     * @param _period The period to check
     * @return _timestamp The timestamp at which the period starts
     */
    function getPeriodStartTime(uint32 periodLength, uint32 periodOffset, uint256 _period)
        internal
        pure
        returns (uint256)
    {
        return _period * periodLength + periodOffset;
    }

    /**
     * @notice Calculates the last timestamp for a period
     * @param periodLength The period length to use to calculate the period
     * @param periodOffset The period offset to use to calculate the period
     * @param _period The period to check
     * @return _timestamp The timestamp at which the period ends
     */
    function getPeriodEndTime(uint32 periodLength, uint32 periodOffset, uint256 _period)
        internal
        pure
        returns (uint256)
    {
        return (_period + 1) * periodLength + periodOffset;
    }

    /**
     * @notice Looks up the newest observation before or at a given timestamp.
     * @dev If an observation is available at the target time, it is returned. Otherwise, the newest observation before the target time is returned.
     * @param _observations The ring buffer of observations
     * @param _accountDetails The account details to query with
     * @param _offsetTargetTime The timestamp to look up (offset by the period offset)
     * @return prevOrAtObservation The observation
     */
    function _getPreviousOrAtObservation(
        ObservationLib.Observation[MAX_CARDINALITY] storage _observations,
        AccountDetails memory _accountDetails,
        PeriodOffsetRelativeTimestamp _offsetTargetTime
    ) private view returns (ObservationLib.Observation memory prevOrAtObservation) {
        // If there are no observations, return a zeroed observation
        if (_accountDetails.bufferCount == 0) {
            return ObservationLib.Observation({cumulativeBalance: 0, balance: 0, timestamp: 0});
        }

        uint16 oldestTwabIndex;

        (oldestTwabIndex, prevOrAtObservation) =
            getOldestObservation(_observations, _accountDetails);

        // if the requested time is older than the oldest observation
        if (PeriodOffsetRelativeTimestamp.unwrap(_offsetTargetTime) < prevOrAtObservation.timestamp)
        {
            // if the user didn't have any activity prior to the oldest observation, then we know they had a zero balance
            if (_accountDetails.bufferCount < MAX_CARDINALITY) {
                return ObservationLib.Observation({
                    cumulativeBalance: 0,
                    balance: 0,
                    timestamp: PeriodOffsetRelativeTimestamp.unwrap(_offsetTargetTime)
                });
            } else {
                // if we are missing their history, we must revert
                revert InsufficientHistory(
                    _offsetTargetTime,
                    PeriodOffsetRelativeTimestamp.wrap(prevOrAtObservation.timestamp)
                );
            }
        }

        // We know targetTime >= oldestObservation.timestamp because of the above if statement, so we can return here.
        if (_accountDetails.bufferCount == 1) {
            return prevOrAtObservation;
        }

        // Find the newest observation
        (uint16 newestTwabIndex, ObservationLib.Observation memory afterOrAtObservation) =
            getNewestObservation(_observations, _accountDetails);

        // if the target time is at or after the newest, return it
        if (
            PeriodOffsetRelativeTimestamp.unwrap(_offsetTargetTime)
                >= afterOrAtObservation.timestamp
        ) {
            return afterOrAtObservation;
        }
        // if we know there is only 1 observation older than the newest
        if (_accountDetails.bufferCount == 2) {
            return prevOrAtObservation;
        }

        // Otherwise, we perform a binarySearch to find the observation before or at the timestamp
        (prevOrAtObservation, oldestTwabIndex, afterOrAtObservation, newestTwabIndex) =
        ObservationLib.binarySearch(
            _observations,
            newestTwabIndex,
            oldestTwabIndex,
            PeriodOffsetRelativeTimestamp.unwrap(_offsetTargetTime),
            _accountDetails.bufferCount
        );

        // After the fix in ObservationLib, `prevOrAtObservation` is now guaranteed to be the correct value
        // (either the exact match or the one immediately preceding the target time).
        // The previous check for `afterOrAtObservation` is no longer necessary.
        return prevOrAtObservation;
    }

    /**
     * @notice Checks if the given timestamp is safe to perform a historic balance lookup on.
     * @dev A timestamp is safe if it is before the current overwrite period
     * @param periodLength The period length to use to calculate the period
     * @param periodOffset The period offset to use to calculate the period
     * @param _time The timestamp to check
     * @return isSafe Whether or not the timestamp is safe
     */
    function hasFinalized(uint32 periodLength, uint32 periodOffset, uint256 _time)
        internal
        view
        returns (bool)
    {
        return _hasFinalized(periodLength, periodOffset, _time);
    }

    /**
     * @notice Checks if the given timestamp is safe to perform a historic balance lookup on.
     * @dev A timestamp is safe if it is on or before the current overwrite period start time
     * @param periodLength The period length to use to calculate the period
     * @param periodOffset The period offset to use to calculate the period
     * @param _time The timestamp to check
     * @return isSafe Whether or not the timestamp is safe
     */
    function _hasFinalized(uint32 periodLength, uint32 periodOffset, uint256 _time)
        private
        view
        returns (bool)
    {
        // It's safe if equal to the overwrite period start time, because the cumulative balance won't be impacted
        return _time <= _currentOverwritePeriodStartedAt(periodLength, periodOffset);
    }

    /**
     * @notice Checks if the given timestamp is safe to perform a historic balance lookup on.
     * @param periodLength The period length to use to calculate the period
     * @param periodOffset The period offset to use to calculate the period
     * @param _timestamp The timestamp to check
     */
    modifier requireFinalized(uint32 periodLength, uint32 periodOffset, uint256 _timestamp) {
        // The current period can still be changed; so the start of the period marks the beginning of unsafe timestamps.
        uint256 overwritePeriodStartTime =
            _currentOverwritePeriodStartedAt(periodLength, periodOffset);
        // timestamp == overwritePeriodStartTime doesn't matter, because the cumulative balance won't be impacted
        if (_timestamp > overwritePeriodStartTime) {
            revert TimestampNotFinalized(_timestamp, overwritePeriodStartTime);
        }
        _;
    }
}
