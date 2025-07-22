// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./_RUSD.Setup.t.sol";

contract TransferFromWithPermit is RUSDSetup {
    function test_ShouldTransferRUSD() public {
        (address owner, uint256 ownerPrivateKey) = makeAddrAndKey("owner");
        address spender = makeAddr("spender");
        uint256 deadline = block.timestamp + 1 days;

        rusd.mint(owner, MINT_AMOUNT, "");

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, MINT_AMOUNT, rusd.nonces(owner), deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked(hex"1901", rusd.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        uint256 balanceBefore = rusd.balanceOf(owner);

        vm.prank(spender);
        rusd.transferFromWithPermit(owner, spender, MINT_AMOUNT, deadline, v, r, s);

        uint256 balanceAfter = rusd.balanceOf(owner);

        assertEq(balanceAfter, balanceBefore - MINT_AMOUNT);
    }
}
