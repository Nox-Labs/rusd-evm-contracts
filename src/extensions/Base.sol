// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

abstract contract Base {
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();

    modifier noZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    modifier noZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }
}
