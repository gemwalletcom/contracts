// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {MulticallHandler} from "../shared/MulticallHandler.sol";

contract GemStargateMulticallHandler is ILayerZeroComposer, MulticallHandler {
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

        // call across

        // Rest from across
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

    receive() external payable {}

    fallback() external payable {}
}
