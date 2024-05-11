// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IStakeHub} from "./interface/IStakeHub.sol";
import {IStakeCredit} from "./interface/IStakeCredit.sol";

struct Validator {
    address operatorAddress;
    bool jailed;
    string moniker;
    uint64 commission;
}

struct Delegation {
    address delegatorAddress;
    address validatorAddress;
    uint256 amount;
}

contract HubReader {
    IStakeHub public stakeHub;

    constructor() {
        stakeHub = IStakeHub(0x0000000000000000000000000000000000002002);
    }

    function getValidators(
        uint16 offset,
        uint16 limit
    ) external view returns (Validator[] memory) {
        (address[] memory operatorAddrs, , uint256 totalLength) = stakeHub
            .getValidators(offset, limit);
        uint256 validatorCount = totalLength < limit ? totalLength : limit;
        Validator[] memory validators = new Validator[](validatorCount);

        for (uint256 i = 0; i < validatorCount; i++) {
            (, bool jailed, ) = stakeHub.getValidatorBasicInfo(
                operatorAddrs[i]
            );
            string memory moniker = stakeHub
                .getValidatorDescription(operatorAddrs[i])
                .moniker;
            uint64 rate = stakeHub
                .getValidatorCommission(operatorAddrs[i])
                .rate;

            validators[i] = Validator({
                operatorAddress: operatorAddrs[i],
                moniker: moniker,
                commission: rate,
                jailed: jailed
            });
        }
        return validators;
    }

    function getDelegations(
        address delegator,
        uint16 offset,
        uint16 limit
    ) external view returns (Delegation[] memory) {
        (
            address[] memory operatorAddrs,
            address[] memory creditAddrs,
            uint256 totalLength
        ) = stakeHub.getValidators(offset, limit);
        uint256 validatorCount = totalLength < limit ? totalLength : limit;
        uint256 delegationCount = 0;
        Delegation[] memory delegations = new Delegation[](validatorCount);

        for (uint256 i = 0; i < validatorCount; i++) {
            IStakeCredit creditContract = IStakeCredit(creditAddrs[i]);
            uint256 amount = creditContract.getPooledBNB(delegator);

            if (amount > 0) {
                delegations[delegationCount] = Delegation({
                    delegatorAddress: delegator,
                    validatorAddress: operatorAddrs[i],
                    amount: amount
                });
                delegationCount++;
            }
        }

        // Resize the array to fit actual number of delegations
        assembly {
            mstore(delegations, delegationCount)
        }
        return delegations;
    }
}
