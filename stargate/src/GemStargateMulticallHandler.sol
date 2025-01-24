// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

contract GemStargateMulticallHandler is ILayerZeroComposer {
    using SafeERC20 for IERC20;
    using Address for address payable;

    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    struct Instructions {
        address token;
        //  Calls that will be attempted.
        Call[] calls;
        // Where the tokens go if any part of the call fails.
        // Leftover tokens are sent here as well if the action succeeds.
        address fallbackRecipient;
    }

    // Emitted when one of the calls fails. Note: all calls are reverted in this case.
    event CallsFailed(Call[] calls, address indexed fallbackRecipient);

    // Emitted when there are leftover tokens that are sent to the fallbackRecipient.
    event DrainedTokens(
        address indexed recipient,
        address indexed token,
        uint256 indexed amount
    );
    event DrainedNative(address indexed recipient, uint256 amount);

    // Errors
    error CallReverted(uint256 index, Call[] calls);
    error NotSelf();
    error InvalidCall(uint256 index, Call[] calls);

    modifier onlySelf() {
        _requireSelf();
        _;
    }

    address public immutable endpoint;

    constructor(address _endpoint) {
        endpoint = _endpoint;
    }

    function lzCompose(
        address, // _from
        bytes32, // _guid
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    ) external payable override {
        require(msg.sender == endpoint, "!endpoint");

        // Decode message
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        Instructions memory instructions = abi.decode(
            composeMsg,
            (Instructions)
        );

        // If there is no fallback recipient, call and revert if the inner call fails.
        if (instructions.fallbackRecipient == address(0)) {
            this.attemptCalls(instructions.calls);
            return;
        }

        // Otherwise, try the call and send to the fallback recipient if any tokens are leftover.
        (bool success, ) = address(this).call(
            abi.encodeCall(this.attemptCalls, (instructions.calls))
        );
        if (!success)
            emit CallsFailed(
                instructions.calls,
                instructions.fallbackRecipient
            );

        // If there are leftover tokens, send them to the fallback recipient regardless of execution success.
        _drainRemainingTokens(
            instructions.token,
            payable(instructions.fallbackRecipient)
        );
    }

    function attemptCalls(Call[] memory calls) external onlySelf {
        uint256 length = calls.length;
        for (uint256 i = 0; i < length; ++i) {
            Call memory call = calls[i];

            // If we are calling an EOA with calldata, assume target was incorrectly specified and revert.
            if (call.callData.length > 0 && call.target.code.length == 0) {
                revert InvalidCall(i, calls);
            }

            (bool success, ) = call.target.call{value: call.value}(
                call.callData
            );
            if (!success) revert CallReverted(i, calls);
        }
    }

    function _drainRemainingTokens(
        address token,
        address payable destination
    ) internal {
        if (token != address(0)) {
            // ERC20 token.
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > 0) {
                IERC20(token).safeTransfer(destination, amount);
                emit DrainedTokens(destination, token, amount);
            }
        } else {
            // Send native token
            uint256 amount = address(this).balance;
            if (amount > 0) {
                destination.sendValue(amount);
                emit DrainedNative(destination, amount);
            }
        }
    }

    function _requireSelf() internal view {
        // Must be called by this contract to ensure that this cannot be triggered without the explicit consent of the
        // depositor (for a valid relay).
        if (msg.sender != address(this)) revert NotSelf();
    }

    receive() external payable {}

    fallback() external payable {}
}
