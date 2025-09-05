// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract Base is Initializable {
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();
    error EmptyBytes();
    error Paused();

    constructor() {
        _disableInitializers();
    }

    modifier noZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    modifier noZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    modifier noEmptyBytes(bytes calldata _bytes) {
        if (_bytes.length == 0) revert EmptyBytes();
        _;
    }
}
