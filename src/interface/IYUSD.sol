// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IYUSD is IERC20Metadata {
    function stake(address user, uint96 amount, bytes calldata data) external;
    function redeem(address user, uint96 amount, bytes calldata data) external;

    function claimRewards(uint32 roundId, address user, address to, uint256 amount) external;
    function claimRewards(uint32 roundId, address user, address to)
        external
        returns (uint256 amount);
    function compoundRewards(uint32 roundId, address user) external;
    function finalizeRound(uint32 roundId) external;
    function changeNextRoundDuration(uint32 duration) external;
    function changeNextRoundBp(uint32 bp) external;

    function getCurrentRoundId() external view returns (uint32);
    function getRoundPeriod(uint32 roundId) external view returns (uint32 start, uint32 end);
    function calculateRewardsRound(uint32 roundId, address user) external view returns (uint256);
    function calculateTotalRewardsRound(uint32 roundId) external view returns (uint256);
    function calculateClaimableRewards(uint32 roundId, address user)
        external
        view
        returns (uint256);

    event NewRound(uint32 roundId, uint32 start, uint32 end);
    event RewardsClaimed(uint32 roundId, address user, address to, uint256 amount);
    event RewardsCompounded(uint32 roundId, address user, uint256 amount);
    event RoundFinalized(uint32 roundId, uint256 amount);
    event RoundDurationChanged(uint32 roundId, uint32 duration);
    event RoundBpChanged(uint32 roundId, uint32 bp);

    error RoundIdUnavailable();
    error RoundNotEnded();
    error RoundAlreadyFinalized();
    error InsufficientRewards(uint256 amount, uint256 claimableRewards);
    error InvalidBp();
    error TwabNotFinalized();

    event Stake(address indexed user, uint256 amount, bytes data);
    event Redeem(address indexed user, uint256 amount, bytes data);
}
