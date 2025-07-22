// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSD.Setup.t.sol";

contract BlacklistableTest is RUSDSetup {
    function test_isBlacklisted_ShouldReturnFalseIfNotBlacklisted() public view {
        assertEq(rusd.isBlacklisted(address(this)), false);
    }

    function test_blacklist_ShouldBlacklistAddress() public {
        rusd.blacklist(address(this));
        assertEq(rusd.isBlacklisted(address(this)), true);
    }

    function test_unBlacklist_ShouldUnblacklistAddress() public {
        rusd.blacklist(address(this));
        rusd.unBlacklist(address(this));
        assertEq(rusd.isBlacklisted(address(this)), false);
    }
}
