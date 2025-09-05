// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSD.Setup.t.sol";

contract RUSDTest is RUSDSetup {
    /* ======== permit ======== */

    function test_ShouldTransferRUSDWithPermit() public {
        (address owner, uint256 ownerPrivateKey) = makeAddrAndKey("owner");
        address spender = makeAddr("spender");
        address to = makeAddr("to");
        uint256 deadline = block.timestamp + 1 days;

        rusd.mint(owner, MINT_AMOUNT, mockData);

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, MINT_AMOUNT, rusd.nonces(owner), deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked(hex"1901", rusd.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        uint256 balanceBefore = rusd.balanceOf(owner);

        vm.prank(spender);
        rusd.permit(owner, spender, MINT_AMOUNT, deadline, v, r, s);
        vm.prank(spender);
        rusd.transferFrom(owner, to, MINT_AMOUNT);

        uint256 balanceAfter = rusd.balanceOf(owner);

        assertEq(balanceAfter, balanceBefore - MINT_AMOUNT);
    }

    function test_RevertIfLowPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.Low);
        vm.expectRevert(Base.Paused.selector);
        vm.prank(user);
        rusd.permit(address(0), address(0), 0, 0, 0, 0, 0);
    }

    /* ======== transfer ======== */

    function test_transfer_RevertIfFromIsBlacklisted() public {
        rusd.blacklist(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(Blacklistable.BlacklistedAccount.selector, address(this))
        );
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

    /* ======== decimals ======== */

    function test_decimals_ShouldReturnDecimals() public view {
        assertEq(rusd.decimals(), 6);
    }
}
