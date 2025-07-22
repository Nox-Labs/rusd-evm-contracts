// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSD.Setup.t.sol";

contract RUSDTest is RUSDSetup {
    /* ======== transfer ======== */

    function test_transfer_RevertIfFromIsBlacklisted() public {
        rusd.blacklist(address(this));
        vm.expectRevert(abi.encodeWithSelector(Blacklistable.Blacklist.selector, address(this)));
        rusd.transfer(user, 100);
    }

    function testFuzz_transfer_ShouldTransferIfFromIsNotBlacklisted(address to, uint256 amount)
        public
    {
        vm.assume(to != address(this) && to != address(0));

        amount = bound(amount, 1, rusd.balanceOf(address(this)));

        rusd.transfer(to, amount);
        assertEq(rusd.balanceOf(to), amount);
    }

    /* ======== upgradeToAndCall ======== */

    function test_upgradeToAndCall_ShouldUpgradeImplementation() public {
        address implementationBefore =
            address(uint160(uint256(vm.load(address(rusd), ERC1967Utils.IMPLEMENTATION_SLOT))));

        address newRUSD = address(new RUSD());
        rusd.upgradeToAndCall(newRUSD, "");

        address implementationAfter =
            address(uint160(uint256(vm.load(address(rusd), ERC1967Utils.IMPLEMENTATION_SLOT))));

        assertNotEq(implementationAfter, implementationBefore);
        assertEq(implementationAfter, newRUSD);
    }

    function test_upgradeToAndCall_RevertIfNotAdmin() public {
        address implementation = address(new RUSD());
        vm.expectRevert(abi.encodeWithSelector(Base.Unauthorized.selector));
        vm.prank(user);
        rusd.upgradeToAndCall(implementation, "");
    }

    /* ======== initialize ======== */

    function test_initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        rusd.initialize(address(this));
    }
}
