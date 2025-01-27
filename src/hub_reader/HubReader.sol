// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IStakeHub} from "./interface/IStakeHub.sol";
import {IStakeCredit} from "./interface/IStakeCredit.sol";

struct Validator {
    address operatorAddress;
    bool jailed;
    string moniker;
    uint64 commission;
    uint64 apy;
}

struct Delegation {
    address delegatorAddress;
    address validatorAddress;
    uint256 amount;
    uint256 shares;
}

struct Undelegation {
    address delegatorAddress;
    address validatorAddress;
    uint256 amount;
    uint256 shares;
    uint256 unlockTime;
}

contract HubReader {
    IStakeHub public stakeHub;

    constructor() {
        stakeHub = IStakeHub(0x0000000000000000000000000000000000002002);
    }

    /*
     * @dev Get validators by offset and limit (pagination), this is an intense function that execution might revert if limit is too large
     * for some node, the best way to call it is to use a batch JSON RPC calls with proper pagination (e.g. 15 or 20 validators per call)

     * @param offset The offset to query validators
     * @param limit The limit to query validators
     *
     * @return The validators
     */
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
                jailed: jailed,
                apy: 0
            });
        }
        uint64[] memory apys = this.getAPYs(operatorAddrs, block.timestamp);
        for (uint256 i = 0; i < validatorCount; i++) {
            validators[i].apy = apys[i];
        }
        return validators;
    }

    /*
     * @dev Get current delegations of a delegator
     * @param delegator The address of the delegator
     * @param offset The offset to query validators
     * @param limit The limit to query validators
     *
     * @return The delegations of the delegator
     */
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
            uint256 shares = creditContract.balanceOf(delegator);
            uint256 amount = creditContract.getPooledBNBByShares(shares);

            if (amount > 0) {
                delegations[delegationCount] = Delegation({
                    delegatorAddress: delegator,
                    validatorAddress: operatorAddrs[i],
                    shares: shares,
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

    /**
     * @dev Get undelegations of a delegator
     * @param delegator The address of the delegator
     * @param offset The offset to query validators
     * @param limit The limit to query validators
     *
     * @return The undelegations of the delegator
     */
    function getUndelegations(
        address delegator,
        uint16 offset,
        uint16 limit
    ) external view returns (Undelegation[] memory) {
        (
            address[] memory operatorAddrs,
            address[] memory creditAddrs,
            uint256 totalLength
        ) = stakeHub.getValidators(offset, limit);
        uint256 validatorCount = totalLength < limit ? totalLength : limit;

        // first loop to get the number of unbond requests
        uint256 undelegationCount = 0;
        for (uint256 i = 0; i < validatorCount; i++) {
            undelegationCount += IStakeCredit(creditAddrs[i])
                .pendingUnbondRequest(delegator);
        }

        Undelegation[] memory undelegations = new Undelegation[](
            undelegationCount
        );

        // resuse same local variable
        undelegationCount = 0;
        for (uint256 i = 0; i < validatorCount; i++) {
            uint256 unbondCount = IStakeCredit(creditAddrs[i])
                .pendingUnbondRequest(delegator);
            for (uint256 j = 0; j < unbondCount; j++) {
                IStakeCredit.UnbondRequest memory req = IStakeCredit(
                    creditAddrs[i]
                ).unbondRequest(delegator, j);
                undelegations[undelegationCount] = Undelegation({
                    delegatorAddress: delegator,
                    validatorAddress: operatorAddrs[i],
                    shares: req.shares,
                    amount: req.bnbAmount,
                    unlockTime: req.unlockTime
                });
                undelegationCount++;
            }
        }
        return undelegations;
    }

    /*
     * @dev Get APYs of an array of validators at a given timestamp
     * @param operatorAddr The address of the validator
     * @param timestamp The timestamp of the block
     *
     * @return The APYs of the validator in basis points, e.g. 195 is 1.95%
     */
    function getAPYs(
        address[] memory operatorAddrs,
        uint256 timestamp
    ) external view returns (uint64[] memory) {
        uint256 dayIndex = timestamp / stakeHub.BREATHE_BLOCK_INTERVAL();
        uint256 length = operatorAddrs.length;
        uint64[] memory apys = new uint64[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 total = stakeHub.getValidatorTotalPooledBNBRecord(
                operatorAddrs[i],
                dayIndex
            );
            if (total == 0) {
                continue;
            }
            uint256 reward = stakeHub.getValidatorRewardRecord(
                operatorAddrs[i],
                dayIndex
            );
            if (reward == 0) {
                continue;
            }
            apys[i] = uint64((reward * 365 * 10000) / total);
        }
        return apys;
    }
}
