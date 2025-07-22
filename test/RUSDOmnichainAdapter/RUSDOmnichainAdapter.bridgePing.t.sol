// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSDOmnichainAdapter.Setup.t.sol";

contract BridgePing is RUSDOmnichainAdapterSetup {
    function testFuzz_ShouldTransferRUSDFromAtoB(uint256 amount) public {
        _checkFuzzAssumptions(amount);

        uint256 balanceBeforeA = rusd.balanceOf(address(this));
        uint256 balanceBeforeB = rusd2.balanceOf(address(this));
        uint256 totalSupplyABefore = rusd.totalSupply();
        uint256 totalSupplyBBefore = rusd2.totalSupply();

        _bridge(endPointB, adapter2, amount);

        uint256 balanceAfterA = rusd.balanceOf(address(this));
        uint256 balanceAfterB = rusd2.balanceOf(address(this));
        uint256 totalSupplyAAfter = rusd.totalSupply();
        uint256 totalSupplyBAfter = rusd2.totalSupply();

        assertEq(balanceAfterA, balanceBeforeA - amount);
        assertEq(balanceAfterB, balanceBeforeB + amount);
        assertEq(totalSupplyAAfter, totalSupplyABefore - amount);
        assertEq(totalSupplyBAfter, totalSupplyBBefore + amount);
    }
}
