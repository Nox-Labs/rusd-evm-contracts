// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IYUSD} from "./interface/IYUSD.sol";
import {IRUSD} from "./interface/IRUSD.sol";

import {TWAB} from "./extensions/TWAB.sol";
import {RUSDDataHubKeeper} from "./extensions/RUSDDataHubKeeper.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

struct RoundInfo {
    uint32 bp;
    uint32 duration;
    bool isFinalized;
    mapping(address user => uint256 claimedRewards) claimedRewards;
}

contract YUSD is IYUSD, TWAB, RUSDDataHubKeeper, UUPSUpgradeable {
    using SafeERC20 for IRUSD;

    uint16 public constant BP_PRECISION = 1e4; // 1% = 100. BP stands for Basis Points.
    uint128 constant INTERNAL_MATH_PRECISION = 1e30;

    /**
     * @notice The total debt of the YUSD contract in RUSD to all users (not including the current round)
     * @notice e.g. if the debt is +100, it means that the YUSD contract have a debt of 100 RUSD to allow all users to claim their rewards.
     * @notice e.g. if the debt is -100, it means that the users in debt of 100 RUSD to the YUSD contract (round not ended yet and final total rewards is not calculated).
     */
    int256 public debt;

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
    ) external initializer {
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

    function getTotalDebt() public view returns (int256) {
        if (debt < 0) return debt;

        return debt + int256(calculateTotalRewardsRound(getCurrentRoundId()));
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

    function getUserRewards(address user, uint32 start, uint32 end)
        public
        view
        returns (uint256[] memory rewards)
    {
        uint32 currentRoundId = getCurrentRoundId();
        if (end == type(uint32).max) end = currentRoundId;

        rewards = new uint256[](end - start + 1);
        for (uint32 i = start; i <= end; i++) {
            rewards[i - start] = calculateRewardsRound(i, user);
        }
    }

    function getRoundInfo(uint32 roundId)
        public
        view
        returns (uint32 bp, uint32 duration, bool isFinalized)
    {
        RoundInfo storage round = _roundInfo[roundId];
        return (round.bp, round.duration, round.isFinalized);
    }

    /* ======== INTERNAL ======== */

    function _claimRewards(uint32 roundId, address user, uint256 amount, address to)
        internal
        noPause
        noZeroAddress(to)
        noZeroAmount(amount)
    {
        _roundInfo[roundId].claimedRewards[user] += amount;
        debt -= int256(amount);
        _getRusd().safeTransfer(to, amount);
    }

    function _getBoundedEnd(uint32 end) internal view returns (uint32) {
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
    ) internal view returns (uint256) {
        uint256 rewardPerSecond =
            Math.mulDiv(twabBalance * INTERNAL_MATH_PRECISION, _roundInfo[roundId].bp, end - start);

        return
            Math.mulDiv(rewardPerSecond, boundedEnd - start, BP_PRECISION * INTERNAL_MATH_PRECISION);
    }

    /* ======== ADMIN ======== */

    function changeNextRoundDuration(uint32 duration) external noZeroAmount(duration) onlyAdmin {
        uint32 nextRoundId = getCurrentRoundId() + 1;
        _roundInfo[nextRoundId].duration = duration;

        emit RoundDurationChanged(nextRoundId, duration);
    }

    function changeNextRoundBp(uint32 bp) external onlyAdmin {
        if (bp > BP_PRECISION) revert InvalidBp();

        uint32 nextRoundId = getCurrentRoundId() + 1;
        _roundInfo[nextRoundId].bp = bp;

        emit RoundBpChanged(nextRoundId, bp);
    }

    function finalizeRound(uint32 roundId) external onlyAdmin {
        RoundInfo storage round = _roundInfo[roundId];

        if (round.isFinalized) revert RoundAlreadyFinalized();
        round.isFinalized = true;

        (, uint32 end) = getRoundPeriod(roundId);

        if (block.timestamp < end) revert RoundNotEnded();

        uint256 totalRewards = calculateTotalRewardsRound(roundId);

        _getRusd().safeTransferFrom(msg.sender, address(this), totalRewards);

        emit RoundFinalized(roundId, totalRewards);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /* ======== MODIFIER ======== */

    modifier updateRoundTimestamps() {
        uint32 currentRoundId = getCurrentRoundId();
        (, uint32 end) = getRoundPeriod(currentRoundId);

        if (block.timestamp >= end) {
            debt += int256(calculateTotalRewardsRound(currentRoundId));
            uint32 nextRoundId = currentRoundId + 1;

            uint32 nextRoundDuration = _roundInfo[nextRoundId].duration;
            uint32 nextRoundBp = _roundInfo[nextRoundId].bp;

            if (nextRoundDuration == 0) nextRoundDuration = _roundInfo[currentRoundId].duration;
            if (nextRoundBp == 0) nextRoundBp = _roundInfo[currentRoundId].bp;

            roundTimestamps.push(end + nextRoundDuration);
            _roundInfo[nextRoundId].bp = nextRoundBp;

            emit NewRound(nextRoundId, end, end + nextRoundDuration);
        }
        _;
    }
}
