// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Message, LzMessageMetadata} from "./interface/IDataTypes.sol";
import {IRUSDOmnichainAdapter} from "./interface/IRUSDOmnichainAdapter.sol";
import {IRUSD} from "./interface/IRUSD.sol";
import {IRUSDDataHub, PauseLevel} from "./interface/IRUSDDataHub.sol";

import {RUSDDataHubKeeper} from "./extensions/RUSDDataHubKeeper.sol";

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

/**
 * @title RUSDOmnichainAdapter
 * @notice The omnichain mint/burn adapter contract.
 * @notice This is separate contract, to allow RUSD to be bridged to other chains through LayerZero.
 */
contract RUSDOmnichainAdapter is
    IRUSDOmnichainAdapter,
    RUSDDataHubKeeper,
    UUPSUpgradeable,
    OAppUpgradeable
{
    using OptionsBuilder for bytes;
    using SafeERC20 for IRUSD;

    /* ======== INITIALIZER ======== */

    /**
     * @notice Initializes the contract.
     * @param _lzEndpoint The address of the LayerZero endpoint.
     * @dev Set the endpoint address in the immutable endpoint variable.
     * @dev This will work properly with proxy contract because the immutable variable works like a constant.
     * @dev This function is empty because we only need to call the parent constructor.
     */
    constructor(address _lzEndpoint) OAppUpgradeable(_lzEndpoint) {}

    /**
     * @notice Initializes the contract.
     * @param _rusdDataHub The address of the RUSDDataHub contract.
     */
    function initialize(IRUSDDataHub _rusdDataHub) public initializer {
        __RUSDDataHubKeeper_init(_rusdDataHub);
        __OApp_init(IRUSDDataHub(_rusdDataHub).getAdmin());
    }

    /* ======== BRIDGE ======== */

    /**
     * @notice Burns RUSD from the caller and sends it to the destination chain.
     * @param _msg The message to send.
     * @param _md The metadata of the message.
     * @notice Emits BridgePing event.
     */
    function bridgePing(Message calldata _msg, LzMessageMetadata memory _md)
        public
        payable
        noPauseLevel(PauseLevel.High)
    {
        if (_msg.to == bytes32(0)) revert ZeroAddress();

        IRUSD rusd = _getRusd();
        rusd.safeTransferFrom(msg.sender, address(this), _msg.amount);
        rusd.burn(_msg.amount);

        MessagingReceipt memory receipt = _sendLzMessage(_msg, _md);

        emit BridgePing(receipt.guid, msg.sender, _msg, _md);
    }

    /**
     * @notice Mints RUSD to the specified address.
     * @param _guid The guid of the message.
     * @param _encodedMessage The encoded message.
     * @notice Emits BridgePong event.
     */
    function _bridgePong(bytes32 _guid, bytes calldata _encodedMessage) internal {
        Message memory message = Message({
            to: OFTMsgCodec.sendTo(_encodedMessage),
            amount: OFTMsgCodec.amountSD(_encodedMessage)
        });
        _getRusd().mint(OFTMsgCodec.bytes32ToAddress(message.to), message.amount);

        emit BridgePong(_guid, message);
    }

    /* ======== INTERNAL ======== */

    /**
     * @notice Sends a message to the destination chain with lzSend.
     * @param _message The message to send.
     * @param _md The metadata of the message.
     */
    function _sendLzMessage(Message calldata _message, LzMessageMetadata memory _md)
        internal
        returns (MessagingReceipt memory)
    {
        (bytes memory message,) = OFTMsgCodec.encode(_message.to, _message.amount, "");

        return _lzSend(_md.dstEid, message, _md.options, _md.fee, _md.refundTo);
    }

    /**
     * @notice Receives a message from the source chain with lzReceive.
     * @param _guid The guid of the message.
     * @param _encodedMessage The encoded message.
     */
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

    /**
     * @notice Quotes the fee for sending a message to the destination chain.
     * @param _dstEid The destination chain id.
     * @param _message The message to send.
     * @param _options The options of the message.
     * @param _payInLzToken Whether to pay in LZ token.
     */
    function quoteSend(
        uint32 _dstEid,
        Message calldata _message,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory) {
        (bytes memory message,) = OFTMsgCodec.encode(_message.to, _message.amount, "");
        return _quote(_dstEid, message, _options, _payInLzToken);
    }

    /**
     * @notice Returns the default LZ options.
     * @notice Contains executorLzReceiveOption with 200k gas and 0 value.
     */
    function defaultLzOptions() public pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(2e5, 0);
    }

    /* ======== ADMIN ======== */

    /**
     * @notice Authorizes the upgrade of the contract.
     * @dev Inherited from UUPSUpgradeable.
     */
    function _authorizeUpgrade(address) internal override onlyAdmin {}

    /**
     * @notice Sets the peer of the contract.
     * @param _eid The destination chain eid.
     * @param _peer The peer of the contract.
     * @dev Inherited from OAppUpgradeable.
     */
    function setPeer(uint32 _eid, bytes32 _peer) public override onlyAdmin {
        _getOAppCoreStorage().peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }
}
