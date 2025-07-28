// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDDataHub.Setup.t.sol";

contract SetAdmin is RUSDDataHubSetup {
    function test_ShouldSetAdmin() public {
        newRUSDDataHub.setAdmin(mockAddress);
        assertEq(newRUSDDataHub.getAdmin(), mockAddress);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        newRUSDDataHub.setAdmin(mockAddress);
    }
}
