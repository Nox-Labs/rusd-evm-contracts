// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IYUSD is IERC20Metadata {
    function mint(address to, uint256 amount, bytes calldata data) external;
    function burn(address from, uint256 amount, bytes calldata data) external;

    function claimRewards(uint32 roundId, uint256 amount, address to) external;
    function claimRewards(uint32 roundId, address to) external returns (uint256 amount);
    function compoundRewards(uint32 roundId) external;
    function payOutRoundRewards(uint32 roundId) external;
    function changeNextRoundDuration(uint32 duration) external;
    function changeNextRoundApr(uint32 apr) external;

    function getCurrentRoundId() external view returns (uint32);
    function getRoundPeriod(uint32 roundId) external view returns (uint32 start, uint32 end);
    function calculateRewardsRound(uint32 roundId, address user) external view returns (uint256);
    function calculateTotalRewardsRound(uint32 roundId) external view returns (uint256);
    function calculateClaimableRewards(uint32 roundId, address user)
        external
        view
        returns (uint256);

    event NewRound(uint32 roundId, uint32 start, uint32 end);
    event RewardsClaimed(uint32 indexed roundId, address from, address to, uint256 amount);
    event RewardsCompounded(uint32 roundId, address from, uint256 amount);
    event RoundRewardsPaidOut(uint32 roundId, uint256 amount);
    event RoundDurationChanged(uint32 duration);
    event RoundAprChanged(uint32 apr);

    error RoundIdUnavailable();
    error RoundNotEnded();
    error InsufficientRewards(uint256 amount, uint256 claimableRewards);

    event Mint(address indexed to, uint256 amount, bytes data);
    event Burn(address indexed from, uint256 amount, bytes data);
}
