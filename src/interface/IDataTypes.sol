// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {MessagingFee} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

struct Message {
    bytes32 to;
    uint64 amount;
}

struct LzMessageMetadata {
    uint32 dstEid;
    bytes options;
    MessagingFee fee;
    bool payInLzToken;
}
