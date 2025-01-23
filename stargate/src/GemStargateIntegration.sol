pragma solidity ^0.8.19;

import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {MessagingFee, OFTReceipt, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract StargateIntegration {
    function prepareTakeTaxi(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg
    )
        external
        view
        returns (
            uint256 valueToSend,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        )
    {
        bytes memory extraOptions = _composeMsg.length > 0
            ? OptionsBuilder.newOptions().addExecutorLzComposeOption(
                0,
                200_000,
                0
            ) // compose gas limit
            : bytes("");

        sendParam = SendParam({
            dstEid: _dstEid,
            to: addressToBytes32(_composer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ""
        });

        IStargate stargate = IStargate(_stargate);

        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        messagingFee = stargate.quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        if (stargate.token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
