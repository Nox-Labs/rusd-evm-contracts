// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSD.Setup.t.sol";

contract Mint is RUSDSetup {
    bytes constant DATA = "https://example.com";

    /* ======== MINT ======== */

    function test_ShouldIncreaseBalance() public {
        uint256 balanceBefore = rusd.balanceOf(address(this));
        vm.prank(address(adapter));
        rusd.mint(address(this), MINT_AMOUNT);
        uint256 balanceAfter = rusd.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + MINT_AMOUNT);
    }

    function test_ShouldIncreaseTotalSupply() public {
        uint256 totalSupplyBefore = rusd.totalSupply();
        vm.prank(address(adapter));
        rusd.mint(address(this), MINT_AMOUNT);
        uint256 totalSupplyAfter = rusd.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore + MINT_AMOUNT);
    }

    function test_RevertIfNotAdapter() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        rusd.mint(user, MINT_AMOUNT);
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        vm.prank(address(adapter));
        rusd.mint(address(this), 0);
    }

    function test_RevertIfZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        vm.prank(address(adapter));
        rusd.mint(address(0), MINT_AMOUNT);
    }

    function test_RevertIfHighPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        vm.prank(address(adapter));
        rusd.mint(address(this), MINT_AMOUNT);
    }

    function test_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IRUSD.Mint(address(this), MINT_AMOUNT, abi.encodePacked(rusd.CROSS_CHAIN()));
        vm.prank(address(adapter));
        rusd.mint(address(this), MINT_AMOUNT);
    }

    /* ======== MINT WITH DATA ======== */

    function test_ShouldIncreaseBalanceWithData() public {
        uint256 balanceBefore = rusd.balanceOf(address(this));
        rusd.mint(address(this), MINT_AMOUNT, DATA);
        uint256 balanceAfter = rusd.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + MINT_AMOUNT);
    }

    function test_ShouldIncreaseTotalSupplyWithData() public {
        uint256 totalSupplyBefore = rusd.totalSupply();
        rusd.mint(address(this), MINT_AMOUNT, DATA);
        uint256 totalSupplyAfter = rusd.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore + MINT_AMOUNT);
    }

    function test_ShouldRevertIfZeroAmountWithData() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        rusd.mint(address(this), 0, DATA);
    }

    function test_ShouldRevertIfZeroAddressWithData() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        rusd.mint(address(0), MINT_AMOUNT, DATA);
    }

    function test_ShouldRevertIfPausedWithData() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        rusd.mint(address(this), MINT_AMOUNT, DATA);
    }

    function test_ShouldEmitEventWithData() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IRUSD.Mint(address(this), MINT_AMOUNT, DATA);

        rusd.mint(address(this), MINT_AMOUNT, DATA);
    }

    function test_ShouldRevertIfNotMinterWithData() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        rusd.mint(user, MINT_AMOUNT, DATA);
    }

    function test_RevertIfZeroBytesWithData() public {
        vm.expectRevert(Base.EmptyBytes.selector);
        rusd.mint(address(this), MINT_AMOUNT, "");
    }

    function test_RevertIfCrossChainActionWithData() public {
        bytes memory data = abi.encodePacked(rusd.CROSS_CHAIN());
        vm.expectRevert(IRUSD.CrossChainActionNotAllowed.selector);
        rusd.mint(address(this), MINT_AMOUNT, data);
    }
}
