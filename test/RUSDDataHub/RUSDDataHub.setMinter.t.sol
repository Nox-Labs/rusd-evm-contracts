// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDDataHub.Setup.t.sol";

contract SetMinter is RUSDDataHubSetup {
    function test_ShouldSetMinter() public {
        newRUSDDataHub.setMinter(mockAddress);
        assertEq(newRUSDDataHub.getMinter(), mockAddress);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        newRUSDDataHub.setMinter(mockAddress);
    }

    function test_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IRUSDDataHub.MinterChanged(mockAddress);
        newRUSDDataHub.setMinter(mockAddress);
    }
}
