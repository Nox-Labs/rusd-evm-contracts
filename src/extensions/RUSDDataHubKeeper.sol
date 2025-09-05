// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IRUSDDataHub, PauseLevel} from "../interface/IRUSDDataHub.sol";
import {IRUSD} from "../interface/IRUSD.sol";
import {Base} from "./Base.sol";

abstract contract RUSDDataHubKeeper is Initializable, Base {
    /// @custom:storage-location erc7201:rusd.storage.RUSDDataHubKeeper
    struct RUSDDataHubKeeperStorage {
        IRUSDDataHub rusdDataHub;
    }

    // keccak256(abi.encode(uint256(keccak256("rusd.storage.RUSDDataHubKeeper")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RUSD_DATA_HUB_KEEPER_STORAGE_LOCATION =
        0xf6c75126fb149fdabc8197aad315689d01deaa3ab6f9a0ac6e9d265d1ad6fe00;

    function __RUSDDataHubKeeper_init(address _rusdDataHub)
        internal
        noZeroAddress(_rusdDataHub)
        onlyInitializing
    {
        _getRUSDDataHubKeeperStorage().rusdDataHub = IRUSDDataHub(_rusdDataHub);
    }

    function _getRUSDDataHubKeeperStorage()
        private
        pure
        returns (RUSDDataHubKeeperStorage storage $)
    {
        assembly {
            $.slot := RUSD_DATA_HUB_KEEPER_STORAGE_LOCATION
        }
    }

    function getRUSDDataHub() public view returns (IRUSDDataHub) {
        return _getRUSDDataHubKeeperStorage().rusdDataHub;
    }

    function _getRusd() internal view returns (IRUSD rusd) {
        rusd = IRUSD(getRUSDDataHub().getRUSD());
    }

    modifier onlyMinter() {
        if (msg.sender != getRUSDDataHub().getMinter()) revert Unauthorized();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != getRUSDDataHub().getAdmin()) revert Unauthorized();
        _;
    }

    modifier onlyAdapter() {
        if (msg.sender != getRUSDDataHub().getOmnichainAdapter()) revert Unauthorized();
        _;
    }

    modifier noPauseLevel(PauseLevel _pauseLevel) {
        if (getRUSDDataHub().getPauseLevel() >= _pauseLevel) revert Paused();
        _;
    }
}
