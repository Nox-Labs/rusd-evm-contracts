// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Message, LzMessageMetadata} from "./interface/IDataTypes.sol";
import {IRUSDOmnichainAdapter} from "./interface/IRUSDOmnichainAdapter.sol";
import {IRUSD} from "./interface/IRUSD.sol";
import {IRUSDDataHub} from "./interface/IRUSDDataHub.sol";

import {RUSDDataHubKeeper} from "src/extensions/RUSDDataHubKeeper.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OAppUpgradeable} from
    "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {
    Origin,
    MessagingFee
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MessagingReceipt} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract RUSDOmnichainAdapter is
    IRUSDOmnichainAdapter,
    RUSDDataHubKeeper,
    UUPSUpgradeable,
    OAppUpgradeable
{
    using OptionsBuilder for bytes;
    using SafeERC20 for IRUSD;

    constructor(address _lzEndpoint) OAppUpgradeable(_lzEndpoint) {}

    function initialize(address _rusdDataHub) public initializer {
        __RUSDDataHubKeeper_init(_rusdDataHub);
        __OApp_init(IRUSDDataHub(_rusdDataHub).getAdmin());
    }

    /* ======== BRIDGE ======== */

    function bridgePing(Message calldata _msg, LzMessageMetadata memory _md) public payable {
        if (_msg.to == bytes32(0)) revert ZeroAddress();

        IRUSD rusd = _getRusd();
        rusd.safeTransferFrom(msg.sender, address(this), _msg.amount);
        rusd.burn(_msg.amount);

        MessagingReceipt memory receipt = _sendLzMessage(_msg, _md);

        emit BridgePing(receipt.guid, msg.sender, _msg, _md);
    }

    function _bridgePong(bytes32 _guid, bytes calldata _encodedMessage) internal {
        Message memory message = Message({
            to: OFTMsgCodec.sendTo(_encodedMessage),
            amount: OFTMsgCodec.amountSD(_encodedMessage)
        });
        _getRusd().mint(OFTMsgCodec.bytes32ToAddress(message.to), message.amount);

        emit BridgePong(_guid, message);
    }

    /* ======== INTERNAL ======== */

    function _sendLzMessage(Message calldata _message, LzMessageMetadata memory _md)
        internal
        returns (MessagingReceipt memory)
    {
        (bytes memory message,) = OFTMsgCodec.encode(_message.to, _message.amount, "");

        return _lzSend(_md.dstEid, message, _md.options, _md.fee, _md.refundTo);
    }

    function _lzReceive(
        Origin calldata, /*_origin*/
        bytes32 _guid,
        bytes calldata _encodedMessage,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        _bridgePong(_guid, _encodedMessage);
    }

    /* ======== VIEW ======== */

    function quoteSend(
        uint32 _dstEid,
        Message calldata _message,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory) {
        (bytes memory message,) = OFTMsgCodec.encode(_message.to, _message.amount, "");
        return _quote(_dstEid, message, _options, _payInLzToken);
    }

    function defaultLzOptions() public pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(3e5, 0);
    }

    /* ======== ADMIN ======== */

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    function setPeer(uint32 _eid, bytes32 _peer) public override onlyAdmin {
        _getOAppCoreStorage().peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }
}
