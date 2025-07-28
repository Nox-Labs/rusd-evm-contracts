// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IRUSDDataHub, IRUSDDataHubMainChain} from "src/interface/IRUSDDataHub.sol";

import {Base} from "src/extensions/Base.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RUSDDataHub is IRUSDDataHub, PausableUpgradeable, UUPSUpgradeable, Base {
    /// @custom:storage-location erc7201:rusd.storage.RUSDDataHub
    struct RUSDDataHubStorage {
        address admin;
        address rusd;
        address yusd;
        address omnichainAdapter;
        address minter;
    }

    // keccak256(abi.encode(uint256(keccak256("rusd.storage.RUSDDataHub")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RUSDDataHubStorageLocation =
        0x394172d64dc9b920f4e550280ee1ad0b974887b563c90cfd38e0a6bcadb26b00;

    function initialize(address _admin, address _minter)
        external
        initializer
        noZeroAddress(_admin)
        noZeroAddress(_minter)
    {
        RUSDDataHubStorage storage $ = _getRUSDDataHubStorage();
        $.admin = _admin;
        $.minter = _minter;
    }

    /* ======== VIEW ======== */

    function getAdmin() public view returns (address) {
        return _getRUSDDataHubStorage().admin;
    }

    function getMinter() public view returns (address) {
        return _getRUSDDataHubStorage().minter;
    }

    function getRUSD() public view returns (address) {
        return _getRUSDDataHubStorage().rusd;
    }

    function getOmnichainAdapter() public view returns (address) {
        return _getRUSDDataHubStorage().omnichainAdapter;
    }

    /* ======== ADMIN ======== */

    function setRUSD(address _rusd) public noZeroAddress(_rusd) onlyAdmin {
        RUSDDataHubStorage storage $ = _getRUSDDataHubStorage();
        if ($.rusd == _rusd) revert AlreadySet();
        $.rusd = _rusd;
    }

    function setOmnichainAdapter(address _omnichainAdapter)
        public
        noZeroAddress(_omnichainAdapter)
        onlyAdmin
    {
        RUSDDataHubStorage storage $ = _getRUSDDataHubStorage();
        if ($.omnichainAdapter == _omnichainAdapter) revert AlreadySet();
        $.omnichainAdapter = _omnichainAdapter;
    }

    function setAdmin(address _admin) public onlyAdmin {
        _getRUSDDataHubStorage().admin = _admin;
    }

    function setMinter(address _minter) public onlyAdmin {
        _getRUSDDataHubStorage().minter = _minter;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    /* ======== INTERNAL ======== */

    function _getRUSDDataHubStorage() internal pure returns (RUSDDataHubStorage storage $) {
        assembly {
            $.slot := RUSDDataHubStorageLocation
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /* ======== MODIFIER ======== */

    modifier onlyAdmin() {
        if (msg.sender != getAdmin()) revert Unauthorized();
        _;
    }
}

contract RUSDDataHubMainChain is IRUSDDataHubMainChain, RUSDDataHub {
    function getYUSD() public view returns (address) {
        return _getRUSDDataHubStorage().yusd;
    }

    function setYUSD(address _yusd) public noZeroAddress(_yusd) onlyAdmin {
        RUSDDataHubStorage storage $ = _getRUSDDataHubStorage();

        if ($.yusd == _yusd) revert AlreadySet();

        $.yusd = _yusd;
    }
}
