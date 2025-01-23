// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

contract GemStargateFeeReceiver is ILayerZeroComposer {
    using SafeERC20 for IERC20;

    struct FeeParams {
        address recipient;       // Final recipient after fees
        address referrerAddress;
        uint256 feeAmount;
        address tokenAddress;    // address(0) for native
    }

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
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable override {
        // Security checks
        require(_from == stargate, "!stargate");
        require(msg.sender == endpoint, "!endpoint");

        // Decode message
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        FeeParams memory params = abi.decode(composeMsg, (FeeParams));

        // Validate fee amount
        if (params.feeAmount == 0 || params.feeAmount > amountLD) {
            revert InvalidFeeAmount();
        }

        if (params.tokenAddress == address(0)) {
            _handleNativeTransfer(params, amountLD);
        } else {
            _handleERC20Transfer(params, amountLD);
        }
    }

    function _handleNativeTransfer(FeeParams memory params, uint256 amountLD) internal {
        // Verify native amount matches
        if (msg.value != amountLD) revert InsufficientNative();
        
        uint256 remaining = amountLD - params.feeAmount;
        
        // Transfer fee to referrer
        (bool successFee, ) = payable(params.referrerAddress).call{value: params.feeAmount}("");
        // Transfer remaining to recipient
        (bool successRemaining, ) = payable(params.recipient).call{value: remaining}("");
        
        if (!successFee || !successRemaining) revert TransferFailed();
    }

    function _handleERC20Transfer(FeeParams memory params, uint256 amountLD) internal {
        IERC20 token = IERC20(params.tokenAddress);
        uint256 remaining = amountLD - params.feeAmount;

        // Verify token balance (protection against fee-on-transfer tokens)
        if (token.balanceOf(address(this)) < amountLD) revert InsufficientNative();

        // Transfer fee to referrer
        token.safeTransfer(params.referrerAddress, params.feeAmount);
        // Transfer remaining to recipient
        token.safeTransfer(params.recipient, remaining);
    }

    receive() external payable {}
}
