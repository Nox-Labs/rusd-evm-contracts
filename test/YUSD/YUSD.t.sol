// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_YUSD.Setup.t.sol";

contract YUSDTest is YUSDSetup {
    /* ======== upgradeToAndCall ======== */

    function test_upgradeToAndCall_ShouldUpgradeImplementation() public {
        address implementationBefore =
            address(uint160(uint256(vm.load(address(yusd), ERC1967Utils.IMPLEMENTATION_SLOT))));

        address newYUSD = address(new YUSD());
        yusd.upgradeToAndCall(newYUSD, "");

        address implementationAfter =
            address(uint160(uint256(vm.load(address(yusd), ERC1967Utils.IMPLEMENTATION_SLOT))));

        assertNotEq(implementationAfter, implementationBefore);
        assertEq(implementationAfter, newYUSD);
    }

    function test_upgradeToAndCall_RevertIfNotAdmin() public {
        address implementation = address(new YUSD());
        vm.expectRevert(abi.encodeWithSelector(Base.Unauthorized.selector));
        vm.prank(user);
        yusd.upgradeToAndCall(implementation, "");
    }

    /* ======== initialize ======== */

    function test_initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        yusd.initialize(address(this), 1, 1, 1, 1);
    }

    /* ======== getCurrentRoundId ======== */

    function test_getCurrentRoundId_ShouldReturnCurrentRoundId() public {
        assertEq(yusd.getCurrentRoundId(), 0);
        skip(roundDuration + 1);
        yusd.stake(address(this), 1, mockData);
        assertEq(yusd.getCurrentRoundId(), 1);
    }

    /* ======== getRoundPeriod ======== */

    function test_getRoundPeriod_ShouldReturnRoundPeriod() public {
        (uint32 start0, uint32 end0) = yusd.getRoundPeriod(0);
        assertEq(start0, block.timestamp);
        assertEq(end0, block.timestamp + roundDuration);

        skip(roundDuration + 1);
        yusd.stake(address(this), 1, mockData);

        (uint32 start1, uint32 end1) = yusd.getRoundPeriod(1);

        assertEq(start1, end0);
        assertEq(end1 + 1, block.timestamp + roundDuration);
    }
}
