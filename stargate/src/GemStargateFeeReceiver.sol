// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

contract GemStargateFeeReceiver is ILayerZeroComposer {
    event Received(address sender, address from);
    event PreparingToPayFee(
        address tokenReceiver,
        address referrer,
        uint256 feeAmount,
        address oftDestinationToken
    );

    error InvalidFeeAmount();
    error InsufficientNative();
    error TransferFailed();

    address public immutable endpoint;
    address public immutable stargate;

    constructor(address _endpoint, address _stargate) {
        endpoint = _endpoint;
        stargate = _stargate;
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable override {
        // Security checks
        emit Received(msg.sender, _from);

        // require(_from == stargate, "!stargate");
        // require(msg.sender == endpoint, "!endpoint");

        // Decode message
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        (
            address _tokenReceiver,
            address _referrer,
            uint256 _feeAmount,
            address _oftDestinationToken
        ) = abi.decode(composeMsg, (address, address, uint256, address));

        emit PreparingToPayFee(
            _tokenReceiver,
            _referrer,
            _feeAmount,
            _oftDestinationToken
        );

        // Validate fee amount
        if (_feeAmount == 0 || _feeAmount > amountLD) {
            revert InvalidFeeAmount();
        }

        if (_oftDestinationToken == address(0)) {
            _handleNativeTransfer(
                _tokenReceiver,
                _referrer,
                _feeAmount,
                amountLD
            );
        } else {
            // TODO: erc20 transfer
        }
    }

    function _handleNativeTransfer(
        address _tokenReceiver,
        address _referrer,
        uint256 _feeAmount,
        uint256 amountLD
    ) internal {
        // Verify native amount matches
        if (msg.value != amountLD) revert InsufficientNative();

        uint256 remaining = amountLD - _feeAmount;

        // Transfer fee to referrer
        (bool successFee, ) = payable(_referrer).call{value: _feeAmount}("");
        // Transfer remaining to recipient
        (bool successRemaining, ) = payable(_tokenReceiver).call{
            value: remaining
        }("");

        if (!successFee || !successRemaining) revert TransferFailed();
    }

    receive() external payable {}

    fallback() external payable {}
}
