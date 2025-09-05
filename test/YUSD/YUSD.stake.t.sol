// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract Stake is YUSDSetup {
    function _afterSetUp() internal override {
        rusd.mint(address(this), 1, mockData);
    }

    function testFuzz_ShouldMintYUSD(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        yusd.stake(address(this), uint96(amount), mockData);

        uint256 balanceAfterYUSD = yusd.balanceOf(address(this));
        uint256 totalSupplyYUSDAfter = yusd.totalSupply();

        assertEq(balanceAfterYUSD, amount);
        assertEq(totalSupplyYUSDAfter, amount);
    }

    function testFuzz_ShouldTransferRUSD(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        uint256 balanceBeforeYUSD = yusd.balanceOf(address(this));
        yusd.stake(address(this), uint96(amount), mockData);
        uint256 balanceAfterYUSD = yusd.balanceOf(address(this));

        assertEq(balanceAfterYUSD, balanceBeforeYUSD + amount);
    }

    function testFuzz_ShouldIncreaseTotalSupply(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        uint256 totalSupplyBefore = yusd.totalSupply();
        yusd.stake(address(this), uint96(amount), mockData);
        uint256 totalSupplyAfter = yusd.totalSupply();

        assertEq(totalSupplyAfter, totalSupplyBefore + amount);
    }

    function test_RevertIfNotAdminOrOmnichainAdapter() public {
        vm.prank(user);
        vm.expectRevert(Base.Unauthorized.selector);
        yusd.stake(address(this), uint96(MINT_AMOUNT), mockData);
    }

    function test_RevertIfHighPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        yusd.stake(address(this), 1, mockData);
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        yusd.stake(address(this), 0, mockData);
    }

    function test_RevertIfZeroAddress() public {
        vm.expectRevert(Base.ZeroAddress.selector);
        yusd.stake(address(0), 1, mockData);
    }

    function test_RevertIfZeroBytes() public {
        vm.expectRevert(Base.EmptyBytes.selector);
        yusd.stake(address(this), MINT_AMOUNT, "");
    }

    function test_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IYUSD.Stake(address(this), MINT_AMOUNT, mockData);
        yusd.stake(address(this), uint96(MINT_AMOUNT), mockData);
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRound() public test_roundTimestampModifier {
        yusd.stake(address(this), 1, mockData);
    }
}
