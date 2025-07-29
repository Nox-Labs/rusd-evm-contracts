// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IYUSD} from "./interface/IYUSD.sol";
import {IRUSD} from "./interface/IRUSD.sol";

import {TWAB} from "./extensions/TWAB.sol";
import {RUSDDataHubKeeper} from "./extensions/RUSDDataHubKeeper.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract YUSD is IYUSD, TWAB, RUSDDataHubKeeper, UUPSUpgradeable {
    using SafeERC20 for IRUSD;

    struct RoundInfo {
        uint32 bp;
        uint32 duration;
        bool isBpSet; // if the bp is set, it means that the admin has changed the bp for this round
        bool isDurationSet; // if the duration is set, it means that the admin has changed the duration for this round
        bool isFinalized;
        mapping(address user => uint256 claimedRewards) claimedRewards;
    }

    uint16 public constant BP_PRECISION = 1e4; // 1% = 100. BP stands for Basis Points.
    uint128 constant INTERNAL_MATH_PRECISION = 1e30;

    /**
     * @notice The total debt of the YUSD contract in RUSD to all users (not including the current round)
     * @notice If totalDebt is positive, it means surplus of RUSD on YUSD contract. (All users can redeem and claim `totalDebt` as rewards) (If all users redeem and claim rewards, the debt will be zero)
     * @notice If totalDebt is negative, it means shortfall of RUSD on YUSD contract. (All users can't redeem and claim whole rewards)
     */
    int256 public totalDebt;

    /**
     * @notice The timestamps of the rounds.
     * @dev The length of the array - 2 is the number of rounds.
     * @dev The first element is the start timestamp of the first round.
     * @dev The second element is the end timestamp of the first round and the start timestamp of the second round.
     * @dev [startTimestampOfRound0, startTimestampOfRound1, startTimestampOfRound2, ...]
     */
    uint32[] public roundTimestamps;

    mapping(uint32 roundId => RoundInfo roundInfo) private _roundInfo;

    function initialize(
        address _rusdDataHub,
        uint32 _periodLength,
        uint32 _firstRoundStartTimestamp,
        uint32 _roundBp,
        uint32 _roundDuration
    )
        external
        initializer
        noZeroAmount(_roundBp)
        noZeroAmount(_roundDuration)
        noZeroAmount(_periodLength)
        noZeroAmount(_firstRoundStartTimestamp)
    {
        if (_roundBp > BP_PRECISION) revert InvalidBp();

        __TWAB_init(_periodLength, _firstRoundStartTimestamp);
        __RUSDDataHubKeeper_init(_rusdDataHub);

        roundTimestamps.push(_firstRoundStartTimestamp);
        roundTimestamps.push(_firstRoundStartTimestamp + _roundDuration);

        RoundInfo storage round = _roundInfo[0];
        round.bp = _roundBp;
        round.duration = _roundDuration;
    }

    /* ======== METADATA ======== */

    function name() public pure returns (string memory) {
        return "YUSD";
    }

    function symbol() public pure returns (string memory) {
        return "YUSD";
    }

    function decimals() public pure returns (uint8) {
        return 6;
    }

    /* ======== MUTATIVE ======== */

    function stake(address user, uint96 amount, bytes calldata data)
        external
        updateRoundTimestamps
        onlyMinter
        noPause
        noZeroAmount(amount)
        noZeroAddress(user)
    {
        _getRusd().safeTransferFrom(msg.sender, address(this), amount);
        _transfer(address(0), user, amount);

        emit Stake(user, amount, data);
    }

    function redeem(address user, uint96 amount, bytes calldata data)
        external
        updateRoundTimestamps
        onlyMinter
        noPause
        noZeroAmount(amount)
    {
        _transfer(user, address(0), amount);
        _getRusd().safeTransfer(msg.sender, amount);

        emit Redeem(user, amount, data);
    }

    function claimRewards(uint32 roundId, address user, address to, uint256 amount)
        external
        updateRoundTimestamps
        onlyMinter
        noZeroAmount(amount)
    {
        uint256 claimableRewards = calculateClaimableRewards(roundId, user);
        if (amount > claimableRewards) revert InsufficientRewards(amount, claimableRewards);

        _claimRewards(roundId, user, amount, to);

        emit RewardsClaimed(roundId, user, to, amount);
    }

    function claimRewards(uint32 roundId, address user, address to)
        external
        updateRoundTimestamps
        onlyMinter
        returns (uint256 rusdAmount)
    {
        rusdAmount = calculateClaimableRewards(roundId, user);
        _claimRewards(roundId, user, rusdAmount, to);

        emit RewardsClaimed(roundId, user, to, rusdAmount);
    }

    function compoundRewards(uint32 roundId, address user)
        external
        updateRoundTimestamps
        onlyMinter
    {
        uint256 claimableRewards = calculateClaimableRewards(roundId, user);
        _claimRewards(roundId, user, claimableRewards, address(this));
        _transfer(address(0), user, uint96(claimableRewards));

        emit RewardsCompounded(roundId, user, claimableRewards);
    }

    /* ======== VIEW ======== */

    function getCurrentRoundId() public view returns (uint32) {
        return uint32(roundTimestamps.length - 2);
    }

    function getRoundPeriod(uint32 roundId) public view returns (uint32 start, uint32 end) {
        if (roundId > getCurrentRoundId()) revert RoundIdUnavailable();

        start = roundTimestamps[roundId];
        end = roundTimestamps[roundId + 1];
    }

    function calculateClaimableRewards(uint32 roundId, address user)
        public
        view
        returns (uint256)
    {
        return calculateRewardsRound(roundId, user) - _roundInfo[roundId].claimedRewards[user];
    }

    function calculateRewardsRound(uint32 roundId, address user) public view returns (uint256) {
        (uint32 start, uint32 end) = getRoundPeriod(roundId);
        uint32 boundedEnd = _getBoundedEnd(end);
        uint256 twabInRound = getTwabBetween(user, start, boundedEnd);
        return _calculateRewardsForTwab(roundId, start, end, boundedEnd, twabInRound);
    }

    function calculateTotalRewardsRound(uint32 roundId) public view returns (uint256) {
        (uint32 start, uint32 end) = getRoundPeriod(roundId);
        uint32 boundedEnd = _getBoundedEnd(end);
        uint256 totalTwabInRound = getTotalSupplyTwabBetween(start, boundedEnd);
        return _calculateRewardsForTwab(roundId, start, end, boundedEnd, totalTwabInRound);
    }

    function getRoundInfo(uint32 roundId)
        public
        view
        returns (uint32 bp, uint32 duration, bool isFinalized)
    {
        RoundInfo storage round = _roundInfo[roundId];
        return (round.bp, round.duration, round.isFinalized);
    }

    /* ======== PRIVATE ======== */

    function _claimRewards(uint32 roundId, address user, uint256 amount, address to)
        private
        noPause
        noZeroAddress(to)
        noZeroAmount(amount)
    {
        _roundInfo[roundId].claimedRewards[user] += amount;
        totalDebt -= int256(amount);
        _getRusd().safeTransfer(to, amount);
    }

    function _getBoundedEnd(uint32 end) private view returns (uint32) {
        uint32 lastSafeTimestamp = uint32(currentOverwritePeriodStartedAt());
        uint32 boundedEnd = uint32(block.timestamp > end ? end : block.timestamp);
        return boundedEnd > lastSafeTimestamp ? lastSafeTimestamp : boundedEnd;
    }

    function _calculateRewardsForTwab(
        uint32 roundId,
        uint32 start,
        uint32 end,
        uint256 boundedEnd,
        uint256 twabBalance
    ) private view returns (uint256) {
        uint256 rewardPerSecond =
            Math.mulDiv(twabBalance * INTERNAL_MATH_PRECISION, _roundInfo[roundId].bp, end - start);

        return
            Math.mulDiv(rewardPerSecond, boundedEnd - start, BP_PRECISION * INTERNAL_MATH_PRECISION);
    }

    /**
     * @notice Start the next round.
     * @dev This function is called when the current round is ended and the transaction triggered with `updateRoundTimestamps` modifier.
     * @dev This function will create next round info base on previous round if admin didn't override it.
     */
    function _startNextRound() private {
        uint32 currentRoundId = getCurrentRoundId();
        uint32 nextRoundId = currentRoundId + 1;

        (, uint32 end) = getRoundPeriod(currentRoundId);

        RoundInfo storage nextRound = _roundInfo[nextRoundId];
        RoundInfo storage currentRound = _roundInfo[currentRoundId];

        uint32 nextRoundDuration = nextRound.duration;
        uint32 nextRoundBp = nextRound.bp;

        if (!nextRound.isDurationSet) nextRoundDuration = currentRound.duration;
        if (!nextRound.isBpSet) nextRoundBp = currentRound.bp;

        roundTimestamps.push(end + nextRoundDuration);
        nextRound.bp = nextRoundBp;
        nextRound.duration = nextRoundDuration;

        emit NewRound(nextRoundId, end, end + nextRoundDuration);
    }

    /* ======== ADMIN ======== */

    function changeNextRoundDuration(uint32 duration) external noZeroAmount(duration) onlyAdmin {
        uint32 nextRoundId = getCurrentRoundId() + 1;
        _roundInfo[nextRoundId].duration = duration;
        _roundInfo[nextRoundId].isDurationSet = true;

        emit RoundDurationChanged(nextRoundId, duration);
    }

    function changeNextRoundBp(uint32 bp) external onlyAdmin {
        if (bp > BP_PRECISION) revert InvalidBp();

        uint32 nextRoundId = getCurrentRoundId() + 1;
        _roundInfo[nextRoundId].bp = bp;
        _roundInfo[nextRoundId].isBpSet = true;

        emit RoundBpChanged(nextRoundId, bp);
    }

    /**
     * @notice Finalize the round.
     * @dev This function is called by admin to finalize the round.
     * @dev This function will transfer the rewards to the YUSD contract from caller.
     */
    function finalizeRound(uint32 roundId) external onlyAdmin {
        RoundInfo storage round = _roundInfo[roundId];

        (, uint32 end) = getRoundPeriod(roundId);

        if (round.isFinalized) revert RoundAlreadyFinalized();
        round.isFinalized = true;

        if (block.timestamp < end) revert RoundNotEnded();

        if (!hasFinalized(end)) revert TwabNotFinalized();

        uint256 totalRewards = calculateTotalRewardsRound(roundId);
        totalDebt += int256(totalRewards);
        _getRusd().safeTransferFrom(msg.sender, address(this), totalRewards);

        emit RoundFinalized(roundId, totalRewards);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /* ======== MODIFIER ======== */

    modifier updateRoundTimestamps() {
        (, uint32 end) = getRoundPeriod(getCurrentRoundId());

        while (block.timestamp >= end) {
            _startNextRound();

            (, end) = getRoundPeriod(getCurrentRoundId());
        }

        _;
    }
}
