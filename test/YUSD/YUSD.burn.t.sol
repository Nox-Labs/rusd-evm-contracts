// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract Burn is YUSDSetup {
    function _afterSetUp() internal override {
        yusd.mint(address(this), MINT_AMOUNT, "");
    }

    function testFuzz_ShouldBurnYUSD(uint256 amount) public {
        amount = bound(amount, 1, MINT_AMOUNT);

        uint256 totalSupplyYUSDBefore = yusd.totalSupply();
        yusd.burn(address(this), amount, "");
        uint256 balanceAfterYUSD = yusd.balanceOf(address(this));
        assertEq(balanceAfterYUSD, totalSupplyYUSDBefore - amount);
    }

    function test_RevertIfPaused() public {
        rusdDataHub.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        yusd.burn(address(this), 1, "");
    }

    function test_RevertIfZeroAmount() public {
        vm.expectRevert(Base.ZeroAmount.selector);
        yusd.burn(address(this), 0, "");
    }

    function test_WithData_ShouldEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), MINT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IYUSD.Burn(address(this), MINT_AMOUNT, "");
        yusd.burn(address(this), MINT_AMOUNT, "");
    }

    function test_ShouldUpdateRoundTimestampAfterFirstRound() public test_roundTimestampModifier {
        yusd.burn(address(this), 1, "");
    }
}
