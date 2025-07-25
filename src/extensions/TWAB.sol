// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {TwabLib} from "../lib/TwabLib.sol";
import {ObservationLib} from "../lib/ObservationLib.sol";

import {Base} from "src/extensions/Base.sol";

/**
 * @title  PoolTogether V5 Time-Weighted Average Balance Controller
 * @author PoolTogether Inc. & G9 Software Inc.
 * @dev    Time-Weighted Average Balance Controller for ERC20 tokens.
 * @notice This TwabController uses the TwabLib to provide token balances and on-chain historical
 *             lookups to a user(s) time-weighted average balance. Each user is mapped to an
 *             Account struct containing the TWAB history (ring buffer) and ring buffer parameters.
 *             Every token.transfer() creates a new TWAB observation. The new TWAB observation is
 *             stored in the circular ring buffer as either a new observation or rewriting a
 *             previous observation with new parameters. One observation per period is stored.
 *             The TwabLib guarantees minimum 1 year of search history if a period is a day.
 */
contract TWAB is Initializable, IERC20, Base {
    using SafeCast for uint256;

    /// @custom:storage-location erc7201:twab.storage.TWAB
    struct TWABStorage {
        /// @notice Sets the minimum period length for Observations. When a period elapses, a new Observation is recorded, otherwise the most recent Observation is updated.
        uint32 periodLength;
        /// @notice Sets the beginning timestamp for the first period. This allows us to maximize storage as well as line up periods with a chosen timestamp.
        /// @dev Ensure that the PERIOD_OFFSET is in the past.
        uint32 periodOffset;
        /// @notice Record of token holders TWABs for each account for each vault.
        mapping(address => TwabLib.Account) userObservations;
        /// @notice Record of allowances for each account for each spender.
        mapping(address account => mapping(address spender => uint256)) allowances;
        /// @notice Record of tickets total supply and ring buff parameters used for observation.
        TwabLib.Account totalSupplyObservations;
    }

    // keccak256(abi.encode(uint256(keccak256("twab.storage.TWAB")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TWABStorageLocation =
        0xd5efd9e6f6b587af2e2d822068ce7fcce37c6c1290968041377a1bfb7c5a0900;

    function _getTWABStorage() private pure returns (TWABStorage storage $) {
        assembly {
            $.slot := TWABStorageLocation
        }
    }
    /**
     * @notice Construct a new TwabController.
     * @dev Reverts if the period offset is in the future.
     * @param _periodLength Sets the minimum period length for Observations. When a period elapses, a new Observation
     *      is recorded, otherwise the most recent Observation is updated.
     * @param _periodOffset Sets the beginning timestamp for the first period. This allows us to maximize storage as well
     *      as line up periods with a chosen timestamp.
     */

    function __TWAB_init(uint32 _periodLength, uint32 _periodOffset) internal onlyInitializing {
        if (_periodOffset > block.timestamp) {
            revert PeriodOffsetInFuture(_periodOffset);
        }

        TWABStorage storage $ = _getTWABStorage();

        $.periodLength = _periodLength;
        $.periodOffset = _periodOffset;
    }

    /* ============ ERC20 Functions ============ */

    function totalSupply() external view returns (uint256) {
        return _getTWABStorage().totalSupplyObservations.details.balance;
    }

    function balanceOf(address user) external view returns (uint256) {
        return _getTWABStorage().userObservations[user].details.balance;
    }

    function transfer(address _to, uint256 _amount) public noZeroAddress(_to) returns (bool) {
        _transfer(msg.sender, _to, uint96(_amount));
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _getTWABStorage().allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount, true);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount)
        public
        noZeroAddress(_from)
        noZeroAddress(_to)
        returns (bool)
    {
        _spendAllowance(_from, msg.sender, _amount);
        _transfer(_from, _to, uint96(_amount));
        return true;
    }

    /**
     * ============ Internal Functions ============
     */
    function _transfer(address _from, address _to, uint96 _amount) internal {
        if (_from != address(0)) {
            _decreaseBalances(_from, _amount);

            if (_to == address(0)) _decreaseTotalSupply(_amount);
        }

        if (_to != address(0)) {
            _increaseBalances(_to, _amount);

            if (_from == address(0)) _increaseTotalSupply(_amount);
        }

        emit Transfer(_from, _to, _amount);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        virtual
        noZeroAddress(owner)
        noZeroAddress(spender)
    {
        _getTWABStorage().allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    /**
     * @notice Increases a user's balance and delegateBalance for a specific vault.
     * @param _user the address of the user whose balance is being increased
     * @param _amount the amount of balance being increased
     */
    function _increaseBalances(address _user, uint96 _amount) internal {
        TWABStorage storage $ = _getTWABStorage();

        TwabLib.Account storage _account = $.userObservations[_user];

        (
            ObservationLib.Observation memory _observation,
            bool _isNewObservation,
            bool _isObservationRecorded,
            TwabLib.AccountDetails memory accountDetails
        ) = TwabLib.increaseBalances($.periodLength, $.periodOffset, _account, _amount);

        // Conditionally emit the observation recorded event
        if (_isObservationRecorded) {
            emit ObservationRecorded(_user, accountDetails.balance, _isNewObservation, _observation);
        }
    }

    /**
     * @notice Decreases the a user's balance and delegateBalance for a specific vault.
     * @param _amount the amount of balance being decreased
     */
    function _decreaseBalances(address _user, uint96 _amount) internal {
        TWABStorage storage $ = _getTWABStorage();
        TwabLib.Account storage _account = $.userObservations[_user];

        (
            ObservationLib.Observation memory _observation,
            bool _isNewObservation,
            bool _isObservationRecorded,
            TwabLib.AccountDetails memory accountDetails
        ) = TwabLib.decreaseBalances(
            $.periodLength, $.periodOffset, _account, _amount, "TWAB/amount-exceeds-balance"
        );

        // Conditionally emit the observation recorded event
        if (_isObservationRecorded) {
            emit ObservationRecorded(_user, accountDetails.balance, _isNewObservation, _observation);
        }
    }

    /**
     * @notice Decreases the totalSupply balance and delegateBalance for a specific vault.
     * @param _amount the amount of balance being decreased
     */
    function _decreaseTotalSupply(uint96 _amount) internal {
        TWABStorage storage $ = _getTWABStorage();
        (
            ObservationLib.Observation memory _observation,
            bool _isNewObservation,
            bool _isObservationRecorded,
            TwabLib.AccountDetails memory accountDetails
        ) = TwabLib.decreaseBalances(
            $.periodLength,
            $.periodOffset,
            $.totalSupplyObservations,
            _amount,
            "TWAB/amount-exceeds-total-supply"
        );

        // Conditionally emit the observation recorded event
        if (_isObservationRecorded) {
            emit TotalSupplyObservationRecorded(
                accountDetails.balance, _isNewObservation, _observation
            );
        }
    }

    /**
     * @notice Increases the totalSupply balance and delegateBalance for a specific vault.
     * @param _amount the amount of balance being increased
     */
    function _increaseTotalSupply(uint96 _amount) internal {
        TWABStorage storage $ = _getTWABStorage();

        (
            ObservationLib.Observation memory _observation,
            bool _isNewObservation,
            bool _isObservationRecorded,
            TwabLib.AccountDetails memory accountDetails
        ) = TwabLib.increaseBalances(
            $.periodLength, $.periodOffset, $.totalSupplyObservations, _amount
        );

        // Conditionally emit the observation recorded event
        if (_isObservationRecorded) {
            emit TotalSupplyObservationRecorded(
                accountDetails.balance, _isNewObservation, _observation
            );
        }
    }

    /* ============ External Read Functions ============ */

    /**
     * @notice Computes the timestamp after which no more observations will be made.
     * @return The largest timestamp at which the TwabController can record a new observation.
     */
    function lastObservationAt() external view returns (uint256) {
        TWABStorage storage $ = _getTWABStorage();
        return TwabLib.lastObservationAt($.periodLength, $.periodOffset);
    }

    // /**
    //  * @notice Loads the current TWAB Account data for a specific vault stored for a user.
    //  * @dev Note this is a very expensive function
    //  * @param user the user whose data is being queried
    //  * @return The current TWAB Account data of the user
    //  */
    // function getAccount(address user) external view returns (TwabLib.Account memory) {
    //     return _getTWABStorage().userObservations[user];
    // }

    // /**
    //  * @notice Loads the current total supply TWAB Account data for a specific vault.
    //  * @dev Note this is a very expensive function
    //  * @return The current total supply TWAB Account data
    //  */
    // function getTotalSupplyAccount() external view returns (TwabLib.Account memory) {
    //     return _getTWABStorage().totalSupplyObservations;
    // }

    // /**
    //  * @notice Looks up a users balance at a specific time in the past.
    //  * @param user the user whose balance is being queried
    //  * @param periodEndOnOrAfterTime The time in the past for which the balance is being queried. The time will be snapped to a period end time on or after the timestamp.
    //  * @return The balance of the user at the target time
    //  */
    // function getBalanceAt(address user, uint256 periodEndOnOrAfterTime)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     TWABStorage storage $ = _getTWABStorage();
    //     TwabLib.Account storage _account = $.userObservations[user];
    //     return TwabLib.getBalanceAt(
    //         $.periodLength,
    //         $.periodOffset,
    //         _account.observations,
    //         _account.details,
    //         _periodEndOnOrAfter(periodEndOnOrAfterTime)
    //     );
    // }

    // /**
    //  * @notice Looks up the total supply at a specific time in the past.
    //  * @param periodEndOnOrAfterTime The time in the past for which the balance is being queried. The time will be snapped to a period end time on or after the timestamp.
    //  * @return The total supply at the target time
    //  */
    // function getTotalSupplyAt(uint256 periodEndOnOrAfterTime) external view returns (uint256) {
    //     TWABStorage storage $ = _getTWABStorage();
    //     TwabLib.Account storage _account = $.totalSupplyObservations;
    //     return TwabLib.getBalanceAt(
    //         $.periodLength,
    //         $.periodOffset,
    //         _account.observations,
    //         _account.details,
    //         _periodEndOnOrAfter(periodEndOnOrAfterTime)
    //     );
    // }

    /**
     * @notice Looks up the average balance of a user between two timestamps.
     * @dev Timestamps are Unix timestamps denominated in seconds
     * @param user the user whose average balance is being queried
     * @param startTime the start of the time range for which the average balance is being queried. The time will be snapped to a period end time on or after the timestamp.
     * @param endTime the end of the time range for which the average balance is being queried. The time will be snapped to a period end time on or after the timestamp.
     * @return The average balance of the user between the two timestamps
     */
    function getTwabBetween(address user, uint256 startTime, uint256 endTime)
        public
        view
        returns (uint256)
    {
        TWABStorage storage $ = _getTWABStorage();
        TwabLib.Account storage _account = $.userObservations[user];
        // We snap the timestamps to the period end on or after the timestamp because the total supply records will be sparsely populated.
        // if two users update during a period, then the total supply observation will only exist for the last one.
        return TwabLib.getTwabBetween(
            $.periodLength,
            $.periodOffset,
            _account.observations,
            _account.details,
            _periodEndOnOrAfter(startTime),
            _periodEndOnOrAfter(endTime)
        );
    }

    // function getTwabBetweenPessimistic(address user, uint256 startTime, uint256 endTime)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     TWABStorage storage $ = _getTWABStorage();
    //     TwabLib.Account storage _account = $.userObservations[user];
    //     return TwabLib.getTwabBetweenPessimistic(
    //         $.periodLength,
    //         $.periodOffset,
    //         _account.observations,
    //         _account.details,
    //         _periodEndOnOrAfter(startTime),
    //         _periodEndOnOrAfter(endTime)
    //     );
    // }

    /**
     * @notice Looks up the average total supply between two timestamps.
     * @dev Timestamps are Unix timestamps denominated in seconds
     * @param startTime the start of the time range for which the average total supply is being queried
     * @param endTime the end of the time range for which the average total supply is being queried
     * @return The average total supply between the two timestamps
     */
    function getTotalSupplyTwabBetween(uint256 startTime, uint256 endTime)
        public
        view
        returns (uint256)
    {
        // We snap the timestamps to the period end on or after the timestamp because the total supply records will be sparsely populated.
        // if two users update during a period, then the total supply observation will only exist for the last one.
        TWABStorage storage $ = _getTWABStorage();
        return TwabLib.getTwabBetween(
            $.periodLength,
            $.periodOffset,
            $.totalSupplyObservations.observations,
            $.totalSupplyObservations.details,
            _periodEndOnOrAfter(startTime),
            _periodEndOnOrAfter(endTime)
        );
    }

    /**
     * @notice Computes the period end timestamp on or after the given timestamp.
     * @param _timestamp The timestamp to check
     * @return The end timestamp of the period that ends on or immediately after the given timestamp
     */
    function periodEndOnOrAfter(uint256 _timestamp) external view returns (uint256) {
        return _periodEndOnOrAfter(_timestamp);
    }

    /**
     * @notice Computes the period end timestamp on or after the given timestamp.
     * @param _timestamp The timestamp to compute the period end time for
     * @return A period end time.
     */
    function _periodEndOnOrAfter(uint256 _timestamp) internal view returns (uint256) {
        TWABStorage storage $ = _getTWABStorage();
        if (_timestamp < $.periodOffset) {
            return $.periodOffset;
        }
        if ((_timestamp - $.periodOffset) % $.periodLength == 0) {
            return _timestamp;
        }
        uint256 period = TwabLib.getTimestampPeriod($.periodLength, $.periodOffset, _timestamp);
        return TwabLib.getPeriodEndTime($.periodLength, $.periodOffset, period);
    }

    // /**
    //  * @notice Looks up the newest observation for a user.
    //  * @param user the user whose observation is being queried
    //  * @return index The index of the observation
    //  * @return observation The observation of the user
    //  */
    // function getNewestObservation(address user)
    //     external
    //     view
    //     returns (uint16, ObservationLib.Observation memory)
    // {
    //     TwabLib.Account storage _account = _getTWABStorage().userObservations[user];
    //     return TwabLib.getNewestObservation(_account.observations, _account.details);
    // }

    // /**
    //  * @notice Looks up the oldest observation for a user.
    //  * @param user the user whose observation is being queried
    //  * @return index The index of the observation
    //  * @return observation The observation of the user
    //  */
    // function getOldestObservation(address user)
    //     external
    //     view
    //     returns (uint16, ObservationLib.Observation memory)
    // {
    //     TwabLib.Account storage _account = _getTWABStorage().userObservations[user];
    //     return TwabLib.getOldestObservation(_account.observations, _account.details);
    // }

    // /**
    //  * @notice Looks up the newest total supply observation for a vault.
    //  * @return index The index of the observation
    //  * @return observation The total supply observation
    //  */
    // function getNewestTotalSupplyObservation()
    //     external
    //     view
    //     returns (uint16, ObservationLib.Observation memory)
    // {
    //     TWABStorage storage $ = _getTWABStorage();
    //     return TwabLib.getNewestObservation(
    //         $.totalSupplyObservations.observations, $.totalSupplyObservations.details
    //     );
    // }

    // /**
    //  * @notice Looks up the oldest total supply observation for a vault.
    //  * @return index The index of the observation
    //  * @return observation The total supply observation
    //  */
    // function getOldestTotalSupplyObservation()
    //     external
    //     view
    //     returns (uint16, ObservationLib.Observation memory)
    // {
    //     TWABStorage storage $ = _getTWABStorage();
    //     return TwabLib.getOldestObservation(
    //         $.totalSupplyObservations.observations, $.totalSupplyObservations.details
    //     );
    // }

    // /**
    //  * @notice Calculates the period a timestamp falls into.
    //  * @param time The timestamp to check
    //  * @return period The period the timestamp falls into
    //  */
    // function getTimestampPeriod(uint256 time) external view returns (uint256) {
    //     TWABStorage storage $ = _getTWABStorage();
    //     return TwabLib.getTimestampPeriod($.periodLength, $.periodOffset, time);
    // }

    /**
     * @notice Checks if the given timestamp is before the current overwrite period.
     * @param time The timestamp to check
     * @return True if the given time is finalized, false if it's during the current overwrite period.
     */
    function hasFinalized(uint256 time) external view returns (bool) {
        TWABStorage storage $ = _getTWABStorage();
        return TwabLib.hasFinalized($.periodLength, $.periodOffset, time);
    }

    /**
     * @notice Computes the timestamp at which the current overwrite period started.
     * @dev The overwrite period is the period during which observations are collated.
     * @return period The timestamp at which the current overwrite period started.
     */
    function currentOverwritePeriodStartedAt() public view returns (uint256) {
        TWABStorage storage $ = _getTWABStorage();
        return TwabLib.currentOverwritePeriodStartedAt($.periodLength, $.periodOffset);
    }

    function getPeriodOffset() public view returns (uint256) {
        return _getTWABStorage().periodOffset;
    }

    function getPeriodLength() public view returns (uint256) {
        return _getTWABStorage().periodLength;
    }

    /* ======== EVENTS ======== */

    /**
     * @notice Emitted when a Total Supply Observation is recorded to the Ring Buffer.
     * @param totalSupply the resulting total supply
     * @param isNew whether the observation is new or not
     * @param observation the observation that was created or updated
     */
    event TotalSupplyObservationRecorded(
        uint96 totalSupply, bool isNew, ObservationLib.Observation observation
    );

    /**
     * @notice Emitted when an Observation is recorded to the Ring Buffer.
     * @param user the users whose Observation was recorded
     * @param balance the resulting balance
     * @param isNew whether the observation is new or not
     * @param observation the observation that was created or updated
     */
    event ObservationRecorded(
        address indexed user, uint96 balance, bool isNew, ObservationLib.Observation observation
    );

    /* ======== ERRORS ======== */
    /// @notice Emitted when the period offset is not in the past.
    /// @param periodOffset The period offset that was passed in
    error PeriodOffsetInFuture(uint32 periodOffset);

    error ERC20InsufficientAllowance(address spender, uint256 currentAllowance, uint256 requested);
}
