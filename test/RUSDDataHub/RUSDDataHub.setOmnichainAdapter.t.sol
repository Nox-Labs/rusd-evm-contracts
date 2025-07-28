// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDDataHub.Setup.t.sol";

contract SetOmnichainAdapter is RUSDDataHubSetup {
    function test_ShouldSetOmnichainAdapter() public {
        newRUSDDataHub.setOmnichainAdapter(mockAddress);
        assertEq(newRUSDDataHub.getOmnichainAdapter(), mockAddress);
    }

    function test_ShouldRevertIfAlreadySet() public {
        newRUSDDataHub.setOmnichainAdapter(mockAddress);
        vm.expectRevert(IRUSDDataHub.AlreadySet.selector);
        newRUSDDataHub.setOmnichainAdapter(mockAddress);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        newRUSDDataHub.setOmnichainAdapter(mockAddress);
    }

    function test_ShouldRevertIfZeroAddress() public {
        vm.expectRevert(Base.ZeroAddress.selector);
        newRUSDDataHub.setOmnichainAdapter(address(0));
    }
}
