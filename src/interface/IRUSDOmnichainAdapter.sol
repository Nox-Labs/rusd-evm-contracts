// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Message, LzMessageMetadata} from "./IDataTypes.sol";

import {MessagingFee} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

interface IRUSDOmnichainAdapter {
    function bridgePing(Message memory _payload, LzMessageMetadata memory _metadata)
        external
        payable;

    function quoteSend(
        uint32 _dstEid,
        Message memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    event BridgePing(
        bytes32 indexed guid, address indexed from, Message payload, LzMessageMetadata metadata
    );
    event BridgePong(bytes32 indexed guid, Message payload);
}
