// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSD.Setup.t.sol";

contract Burn is RUSDSetup {
    bytes constant DATA = abi.encodePacked(keccak256("mockData"));

    function _afterSetUp() internal override {
        vm.prank(address(adapter));
        rusd.mint(address(adapter), MINT_AMOUNT);
    }

    /* ======== BURN  ======== */

    function test_ShouldDecreaseBalance() public {
        uint256 balanceBefore = rusd.balanceOf(address(adapter));
        vm.prank(address(adapter));
        rusd.burn(MINT_AMOUNT);
        uint256 balanceAfter = rusd.balanceOf(address(adapter));
        assertEq(balanceAfter, balanceBefore - MINT_AMOUNT);
    }

    function test_ShouldDecreaseTotalSupply() public {
        uint256 totalSupplyBefore = rusd.totalSupply();
        vm.prank(address(adapter));
        rusd.burn(MINT_AMOUNT);
        uint256 totalSupplyAfter = rusd.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore - MINT_AMOUNT);
    }

    function test_RevertIfNotAdminOrAdapter() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        rusd.burn(MINT_AMOUNT);
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        vm.prank(address(adapter));
        rusd.burn(0);
    }

    function test_RevertIfHighPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        vm.prank(address(adapter));
        rusd.burn(MINT_AMOUNT);
    }

    function test_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(adapter), address(0), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IRUSD.Burn(address(adapter), MINT_AMOUNT, abi.encodePacked(rusd.CROSS_CHAIN()));
        vm.prank(address(adapter));
        rusd.burn(MINT_AMOUNT);
    }

    /* ======== BURN WITH DATA ======== */

    function test_ShouldDecreaseBalanceWithData() public {
        uint256 balanceBefore = rusd.balanceOf(address(this));
        rusd.burn(MINT_AMOUNT, DATA);
        uint256 balanceAfter = rusd.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - MINT_AMOUNT);
    }

    function test_ShouldDecreaseTotalSupplyWithData() public {
        uint256 totalSupplyBefore = rusd.totalSupply();
        rusd.burn(MINT_AMOUNT, DATA);
        uint256 totalSupplyAfter = rusd.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore - MINT_AMOUNT);
    }

    function test_RevertIfZeroAmountWithData() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        rusd.burn(0, DATA);
    }

    function test_RevertIfZeroBytesWithData() public {
        vm.expectRevert(Base.EmptyBytes.selector);
        rusd.burn(MINT_AMOUNT, "");
    }

    function test_RevertIfCrossChainActionWithData() public {
        bytes memory data = abi.encodePacked(rusd.CROSS_CHAIN());
        vm.expectRevert(IRUSD.CrossChainActionNotAllowed.selector);
        rusd.burn(MINT_AMOUNT, data);
    }

    function test_RevertIfHighPausedWithData() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        rusd.burn(MINT_AMOUNT, DATA);
    }

    function test_RevertIfNotMinterWithData() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        rusd.burn(MINT_AMOUNT, DATA);
    }

    function test_ShouldEmitEventWithData() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IRUSD.Burn(address(this), MINT_AMOUNT, DATA);
        vm.prank(address(this));
        rusd.burn(MINT_AMOUNT, DATA);
    }
}
