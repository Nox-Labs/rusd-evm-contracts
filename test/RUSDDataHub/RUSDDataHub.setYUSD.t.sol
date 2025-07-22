// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDDataHub.Setup.t.sol";

contract SetYUSD is RUSDDataHubSetup {
    function test_ShouldSetYUSD() public {
        newRUSDDataHub.setYUSD(mockAddress);
        assertEq(newRUSDDataHub.getYUSD(), mockAddress);
    }

    function test_ShouldRevertIfAlreadySet() public {
        newRUSDDataHub.setYUSD(mockAddress);
        vm.expectRevert(IRUSDDataHub.AlreadySet.selector);
        newRUSDDataHub.setYUSD(mockAddress);
    }

    function test_ShouldRevertIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        newRUSDDataHub.setYUSD(mockAddress);
    }

    function test_ShouldRevertIfZeroAddress() public {
        vm.expectRevert(Base.ZeroAddress.selector);
        newRUSDDataHub.setYUSD(address(0));
    }
}
