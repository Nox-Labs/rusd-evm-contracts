// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.20;

import "./_RUSDDataHub.Setup.t.sol";

contract RUSDDataHubTest is RUSDDataHubSetup {
    /* ======== pause ======== */

    function test_pause_ShouldPause() public {
        rusdDataHub.pause();
        assertEq(rusdDataHub.paused(), true);
    }

    function test_pause_RevertIfNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Base.Unauthorized.selector));
        vm.prank(user);
        rusdDataHub.pause();
    }

    /* ======== unpause ======== */

    function test_unpause_ShouldUnpause() public {
        rusdDataHub.pause();
        rusdDataHub.unpause();
        assertEq(rusdDataHub.paused(), false);
    }

    function test_unpause_RevertIfNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Base.Unauthorized.selector));
        vm.prank(user);
        rusdDataHub.unpause();
    }

    /* ======== upgradeToAndCall ======== */

    function test_upgradeToAndCall_ShouldUpgradeImplementation() public {
        address implementationBefore = address(
            uint160(uint256(vm.load(address(rusdDataHub), ERC1967Utils.IMPLEMENTATION_SLOT)))
        );

        address newRUSDDataHub = address(new RUSDDataHub());
        rusdDataHub.upgradeToAndCall(newRUSDDataHub, "");

        address implementationAfter = address(
            uint160(uint256(vm.load(address(rusdDataHub), ERC1967Utils.IMPLEMENTATION_SLOT)))
        );

        assertNotEq(implementationAfter, implementationBefore);
        assertEq(implementationAfter, newRUSDDataHub);
    }

    function test_upgradeToAndCall_RevertIfNotAdmin() public {
        address implementation = address(new RUSDDataHub());
        vm.expectRevert(abi.encodeWithSelector(Base.Unauthorized.selector));
        vm.prank(user);
        rusdDataHub.upgradeToAndCall(implementation, "");
    }

    /* ======== getAdmin ======== */

    function test_getAdmin_ShouldReturnAdmin() public view {
        assertEq(rusdDataHub.getAdmin(), address(this));
    }

    /* ======== getOmnichainAdapter ======== */

    function test_getOmnichainAdapter_ShouldReturnOmnichainAdapter() public view {
        assertEq(rusdDataHub.getOmnichainAdapter(), address(adapter));
    }

    /* ======== getRUSD ======== */

    function test_getRUSD_ShouldReturnRUSD() public view {
        assertEq(rusdDataHub.getRUSD(), address(rusd));
    }

    /* ======== getYUSD ======== */

    function test_getYUSD_ShouldReturnYUSD() public view {
        assertEq(rusdDataHub.getYUSD(), address(yusd));
    }

    /* ======== initialize ======== */

    function test_initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        rusdDataHub.initialize(address(this), address(this));
    }
}
