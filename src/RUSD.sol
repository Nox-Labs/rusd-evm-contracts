// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IRUSD, IERC20Metadata} from "src/interface/IRUSD.sol";

import {Blacklistable} from "src/extensions/Blacklistable.sol";
import {RUSDDataHubKeeper} from "src/extensions/RUSDDataHubKeeper.sol";

import {
    ERC20PermitUpgradeable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RUSD is
    IRUSD,
    Blacklistable,
    RUSDDataHubKeeper,
    UUPSUpgradeable,
    ERC20PermitUpgradeable
{
    bytes32 public constant CROSS_CHAIN = keccak256("CROSS_CHAIN");

    function initialize(address _rusdDataHub) public initializer {
        __RUSDDataHubKeeper_init(_rusdDataHub);
        __ERC20_init("RUSD", "RUSD");
        __ERC20Permit_init(name());
    }

    function decimals() public pure override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount, bytes calldata data)
        public
        noZeroAmount(amount)
        validateData(data)
        onlyMinter
    {
        _mint(to, amount);
        emit Mint(to, amount, data);
    }

    function burn(uint256 amount, bytes calldata data)
        public
        noZeroAmount(amount)
        validateData(data)
        onlyMinter
    {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount, data);
    }

    function mint(address to, uint256 amount) public noZeroAmount(amount) onlyAdapter {
        _mint(to, amount);
        emit Mint(to, amount, abi.encodePacked(CROSS_CHAIN));
    }

    function burn(uint256 amount) public noZeroAmount(amount) onlyAdapter {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount, abi.encodePacked(CROSS_CHAIN));
    }

    function _update(address from, address to, uint256 amount)
        internal
        virtual
        override
        notBlacklisted(from)
        notBlacklisted(to)
        noPause
    {
        super._update(from, to, amount);
    }

    function _authorizeUpgrade(address) internal view override onlyAdmin {}
    function _authorizeBlacklist() internal view override onlyAdmin {}

    /* ======== MODIFIERS ======== */
    modifier validateData(bytes calldata data) {
        if (data.length == 0) revert DataLengthZero();
        if (bytes32(data) == CROSS_CHAIN) revert CrossChainActionNotAllowed();

        _;
    }
}
