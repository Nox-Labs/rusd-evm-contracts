// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract Redeem is YUSDSetup {
    function _afterSetUp() internal override {
        yusd.stake(address(this), MINT_AMOUNT, mockData);
    }

    function testFuzz_ShouldBurnYUSD(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        uint256 totalSupplyYUSDBefore = yusd.totalSupply();
        yusd.redeem(address(this), uint96(amount), mockData);
        uint256 balanceAfterYUSD = yusd.balanceOf(address(this));
        assertEq(balanceAfterYUSD, totalSupplyYUSDBefore - amount);
    }

    function test_RevertIfHighPaused() public {
        rusdDataHub.setPauseLevel(PauseLevel.High);
        vm.expectRevert(Base.Paused.selector);
        yusd.redeem(address(this), 1, mockData);
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        yusd.redeem(address(this), 0, mockData);
    }

    function test_RevertIfZeroBytes() public {
        vm.expectRevert(Base.EmptyBytes.selector);
        yusd.redeem(address(this), MINT_AMOUNT, "");
    }

    function test_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IYUSD.Redeem(address(this), MINT_AMOUNT, mockData);
        yusd.redeem(address(this), MINT_AMOUNT, mockData);
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRound() public test_roundTimestampModifier {
        yusd.redeem(address(this), 1, mockData);
    }
}
