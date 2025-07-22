// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDDataHub.Setup.t.sol";

contract SetRUSD is RUSDDataHubSetup {
    function test_ShouldSetRUSD() public {
        newRUSDDataHub.setRUSD(mockAddress);
        assertEq(newRUSDDataHub.getRUSD(), mockAddress);
    }

    function test_ShouldRevertIfAlreadySet() public {
        newRUSDDataHub.setRUSD(mockAddress);
        vm.expectRevert(IRUSDDataHub.AlreadySet.selector);
        newRUSDDataHub.setRUSD(mockAddress);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        newRUSDDataHub.setRUSD(mockAddress);
    }

    function test_ShouldRevertIfZeroAddress() public {
        vm.expectRevert(Base.ZeroAddress.selector);
        newRUSDDataHub.setRUSD(address(0));
    }
}
