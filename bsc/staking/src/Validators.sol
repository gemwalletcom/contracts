// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IStakeHub, Description, Commission} from "./interface/IStakeHub.sol";

struct Validator {
    address operatorAddress;
    address creditAddress;
    bool jailed;
    uint256 jailUntil;
    string moniker;
    uint64 commission;
}

contract ValidatorsReader {
    address STAKEHUB_ADDRESS = 0x0000000000000000000000000000000000002002;
    IStakeHub public stakeHub;

    constructor() {
        stakeHub = IStakeHub(STAKEHUB_ADDRESS);
    }

    function getValidators(
        uint256 offset,
        uint256 limit
    ) external view returns (Validator[] memory) {
        (
            address[] memory operatorAddrs,
            address[] memory creditAddrs,
            uint256 totalLength
        ) = stakeHub.getValidators(offset, limit);

        uint256 validatorCount = totalLength < limit ? totalLength : limit;
        Validator[] memory validators = new Validator[](validatorCount);

        for (uint256 i = 0; i < validatorCount; i++) {
            (, bool jailed, uint256 jailUntil) = stakeHub.getValidatorBasicInfo(
                operatorAddrs[i]
            );

            Description memory description = stakeHub.getValidatorDescription(
                operatorAddrs[i]
            );
            Commission memory commission = stakeHub.getValidatorCommission(
                operatorAddrs[i]
            );

            validators[i] = Validator({
                operatorAddress: operatorAddrs[i],
                creditAddress: creditAddrs[i],
                jailed: jailed,
                jailUntil: jailUntil,
                moniker: description.moniker,
                commission: commission.rate
            });
        }
        return validators;
    }
}
