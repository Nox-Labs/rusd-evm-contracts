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

    uint16 public constant APR_PRECISION = 10000; // 1% = 100
    uint128 constant INTERNAL_MATH_PRECISION = 1e30;

    uint32 public nextRoundDuration;
    uint32 public nextRoundApr;

    // total debt of the YUSD contract in RUSD to all users (not including the current round)
    int256 private _debt;

    /**
     * @notice The timestamps of the rounds.
     * @dev The length of the array - 2 is the number of rounds.
     * @dev The first element is the start timestamp of the first round.
     * @dev The second element is the end timestamp of the first round and the start timestamp of the second round.
     * @dev [startTimestampOfRound0, startTimestampOfRound1, startTimestampOfRound2, ...]
     */
    uint32[] public roundTimestamps;

    mapping(uint32 roundId => uint32 apr) public roundApr;
    mapping(uint32 roundId => mapping(address user => uint256)) public roundRewardsClaimed;

    function initialize(
        address _rusdDataHub,
        uint32 _periodLength,
        uint32 _firstRoundStartTimestamp,
        uint32 _roundApr,
        uint32 _roundDuration
    ) external initializer {
        __TWAB_init(_periodLength, _firstRoundStartTimestamp);
        __RUSDDataHubKeeper_init(_rusdDataHub);

        nextRoundApr = _roundApr;
        nextRoundDuration = _roundDuration;

        roundTimestamps.push(_firstRoundStartTimestamp);
        roundTimestamps.push(_firstRoundStartTimestamp + _roundDuration);

        roundApr[0] = _roundApr;
    }

    /* ======== MUTATIVE ======== */

    function mint(address to, uint256 amount, bytes calldata data)
        external
        updateRoundTimestamps
        onlyMinter
        noZeroAmount(amount)
        noZeroAddress(to)
        noPause
    {
        _transfer(address(0), to, uint96(amount));
        emit Mint(to, amount, data);
    }

    function burn(address from, uint256 amount, bytes calldata data)
        external
        updateRoundTimestamps
        noPause
        noZeroAmount(amount)
        onlyMinter
    {
        _transfer(from, address(0), uint96(amount));
        emit Burn(from, amount, data);
    }

    function claimRewards(uint32 roundId, uint256 amount, address to)
        external
        updateRoundTimestamps
        noZeroAmount(amount)
    {
        uint256 claimableRewards = calculateClaimableRewards(roundId, msg.sender);
        if (amount > claimableRewards) revert InsufficientRewards(amount, claimableRewards);

        _claimRewards(roundId, amount, to);

        emit RewardsClaimed(roundId, msg.sender, to, amount);
    }

    function claimRewards(uint32 roundId, address to)
        external
        updateRoundTimestamps
        returns (uint256 rusdAmount)
    {
        rusdAmount = calculateClaimableRewards(roundId, msg.sender);
        _claimRewards(roundId, rusdAmount, to);

        emit RewardsClaimed(roundId, msg.sender, to, rusdAmount);
    }

    function compoundRewards(uint32 roundId) external updateRoundTimestamps {
        uint256 claimableRewards = calculateClaimableRewards(roundId, msg.sender);
        _claimRewards(roundId, claimableRewards, address(this));
        _transfer(address(0), msg.sender, uint96(claimableRewards));

        emit RewardsCompounded(roundId, msg.sender, claimableRewards);
    }

    /* ======== INTERNAL ======== */

    function _claimRewards(uint32 roundId, uint256 amount, address to) internal noPause {
        roundRewardsClaimed[roundId][msg.sender] += amount;
        _debt -= int256(amount);
        _getRusd().safeTransfer(to, amount);
    }

    /* ======== VIEW ======== */

    function name() public pure returns (string memory) {
        return "YUSD";
    }

    function symbol() public pure returns (string memory) {
        return "YUSD";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function getTotalDebt() public view returns (uint256) {
        return uint256(int256(calculateTotalRewardsRound(getCurrentRoundId())) + _debt);
    }

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
        return calculateRewardsRound(roundId, user) - roundRewardsClaimed[roundId][user];
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

    /* ======== INTERNAL ======== */

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
            Math.mulDiv(twabBalance * INTERNAL_MATH_PRECISION, roundApr[roundId], end - start);

        return Math.mulDiv(
            rewardPerSecond, boundedEnd - start, APR_PRECISION * INTERNAL_MATH_PRECISION
        );
    }

    /* ======== ADMIN ======== */

    function changeNextRoundDuration(uint32 duration) external onlyAdmin {
        nextRoundDuration = duration;

        emit RoundDurationChanged(nextRoundDuration);
    }

    function changeNextRoundApr(uint32 apr) external onlyAdmin {
        nextRoundApr = apr;

        emit RoundAprChanged(nextRoundApr);
    }

    function payOutRoundRewards(uint32 roundId) external onlyAdmin {
        (, uint32 end) = getRoundPeriod(roundId);

        if (block.timestamp < end) revert RoundNotEnded();

        uint256 totalRewards = calculateTotalRewardsRound(roundId);

        _getRusd().transferFrom(msg.sender, address(this), totalRewards);

        emit RoundRewardsPaidOut(roundId, totalRewards);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /* ======== MODIFIER ======== */

    modifier updateRoundTimestamps() {
        uint32 currentRoundId = getCurrentRoundId();
        (, uint32 end) = getRoundPeriod(currentRoundId);

        if (block.timestamp > end) {
            _debt += int256(calculateTotalRewardsRound(currentRoundId));
            uint32 nextRoundId = currentRoundId + 1;

            roundTimestamps.push(end + nextRoundDuration);
            roundApr[nextRoundId] = nextRoundApr;

            emit NewRound(nextRoundId, end, end + nextRoundDuration);
        }
        _;
    }
}
