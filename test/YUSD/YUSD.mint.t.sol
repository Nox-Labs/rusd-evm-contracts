// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract Mint is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(this), 1, "");
    }

    function testFuzz_ShouldMintYUSD(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        yusd.mint(address(this), amount, "");

        uint256 balanceAfterYUSD = yusd.balanceOf(address(this));
        uint256 totalSupplyYUSDAfter = yusd.totalSupply();

        assertEq(balanceAfterYUSD, amount);
        assertEq(totalSupplyYUSDAfter, amount);
    }

    function testFuzz_ShouldTransferRUSD(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        uint256 balanceBeforeYUSD = yusd.balanceOf(address(this));
        yusd.mint(address(this), amount, "");
        uint256 balanceAfterYUSD = yusd.balanceOf(address(this));

        assertEq(balanceAfterYUSD, balanceBeforeYUSD + amount);
    }

    function testFuzz_ShouldIncreaseTotalSupply(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        uint256 totalSupplyBefore = yusd.totalSupply();
        yusd.mint(address(this), amount, "");
        uint256 totalSupplyAfter = yusd.totalSupply();

        assertEq(totalSupplyAfter, totalSupplyBefore + amount);
    }

    function test_RevertIfNotAdminOrOmnichainAdapter() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        yusd.mint(address(this), MINT_AMOUNT, "");
    }

    function test_RevertIfPaused() public {
        rusdDataHub.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        yusd.mint(address(this), 1, "");
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        yusd.mint(address(this), 0, "");
    }

    function test_RevertIfZeroAddress() public {
        vm.expectRevert(Base.ZeroAddress.selector);
        yusd.mint(address(0), 1, "");
    }

    function test_WithData_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IYUSD.Mint(address(this), MINT_AMOUNT, "");
        yusd.mint(address(this), MINT_AMOUNT, "");
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRound() public test_roundTimestampModifier {
        yusd.mint(address(this), 1, "");
    }
}
