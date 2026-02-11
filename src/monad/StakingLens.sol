// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IStaking} from "./IStaking.sol";

contract StakingLens {
    using Strings for uint256;

    IStaking public constant STAKING = IStaking(0x0000000000000000000000000000000000001000);

    uint16 public constant MAX_DELEGATIONS = 128;
    uint8 public constant MAX_WITHDRAW_IDS = 8;
    uint32 public constant ACTIVE_VALIDATOR_SET = 200;
    uint256 public constant MAX_POSITIONS = uint256(MAX_DELEGATIONS) * (2 + MAX_WITHDRAW_IDS);

    uint256 public constant MONAD_SCALE = 1e18;
    uint256 public constant MONAD_BLOCK_REWARD = 25 ether;
    uint256 public constant MONAD_BLOCKS_PER_YEAR = 78_840_000;
    uint64 public constant APY_BPS_PRECISION = 10_000;
    uint64 public constant MONAD_BOUNDARY_BLOCK_PERIOD = 50_000;
    uint64 public constant MONAD_EPOCH_SECONDS = MONAD_BOUNDARY_BLOCK_PERIOD * 2 / 5; // 0.4s blocks

    enum DelegationState {
        Active,
        Activating,
        Deactivating,
        AwaitingWithdrawal
    }

    struct Delegation {
        uint64 validatorId;
        uint8 withdrawId;
        DelegationState state;
        uint256 amount;
        uint256 rewards;
        uint64 withdrawEpoch;
        uint64 completionTimestamp;
    }

    struct DelegatorSnapshot {
        uint256 stake;
        uint256 pendingStake;
        uint256 rewards;
    }

    struct ValidatorInfo {
        uint64 validatorId;
        uint256 stake;
        uint256 commission;
        uint64 apyBps;
        bool isActive;
    }

    struct ValidatorData {
        uint64 validatorId;
        uint64 flags;
        uint256 stake;
        uint256 commission;
    }

    function getBalance(address delegator) external returns (uint256 staked, uint256 pending, uint256 rewards) {
        bool isDone;
        uint64 nextValId;
        uint64[] memory valIds;

        (isDone, nextValId, valIds) = STAKING.getDelegations(delegator, 0);

        while (true) {
            uint256 len = valIds.length;

            for (uint256 i = 0; i < len; ++i) {
                (uint256 stake,, uint256 unclaimedRewards, uint256 deltaStake, uint256 nextDeltaStake,,) =
                    STAKING.getDelegator(valIds[i], delegator);

                staked += stake;
                pending += deltaStake + nextDeltaStake;
                rewards += unclaimedRewards;
            }

            if (isDone) {
                break;
            }

            (isDone, nextValId, valIds) = STAKING.getDelegations(delegator, nextValId);
        }
    }

    function getDelegations(address delegator) external returns (Delegation[] memory positions) {
        positions = new Delegation[](MAX_POSITIONS);
        uint256 positionCount = 0;
        uint16 validatorCount = 0;
        uint64[] memory processedValidatorIds = new uint64[](uint256(MAX_DELEGATIONS));
        uint256 processedValidatorCount = 0;

        (uint64 currentEpoch,) = STAKING.getEpoch();

        bool isDone;
        uint64 nextValId;
        uint64[] memory valIds;

        (isDone, nextValId, valIds) = STAKING.getDelegations(delegator, 0);

        while (true) {
            uint256 len = valIds.length;

            for (uint256 i = 0; i < len && validatorCount < MAX_DELEGATIONS; ++i) {
                uint64 validatorId = valIds[i];
                if (_containsValidator(processedValidatorIds, processedValidatorCount, validatorId)) {
                    continue;
                }

                positionCount = _processValidator(delegator, validatorId, currentEpoch, positions, positionCount);
                processedValidatorIds[processedValidatorCount] = validatorId;
                ++processedValidatorCount;
                ++validatorCount;
            }

            if (isDone || validatorCount == MAX_DELEGATIONS || positionCount == MAX_POSITIONS) {
                break;
            }

            (isDone, nextValId, valIds) = STAKING.getDelegations(delegator, nextValId);
        }

        if (validatorCount < MAX_DELEGATIONS && positionCount < MAX_POSITIONS) {
            uint64[] memory allValidatorIds = _allValidatorIds();
            uint256 len = allValidatorIds.length;
            for (uint256 i = 0; i < len && validatorCount < MAX_DELEGATIONS && positionCount < MAX_POSITIONS; ++i) {
                uint64 validatorId = allValidatorIds[i];
                if (_containsValidator(processedValidatorIds, processedValidatorCount, validatorId)) {
                    continue;
                }

                positionCount = _processValidator(delegator, validatorId, currentEpoch, positions, positionCount);
                processedValidatorIds[processedValidatorCount] = validatorId;
                ++processedValidatorCount;
                ++validatorCount;
            }
        }

        assembly {
            mstore(positions, positionCount)
        }
    }

    function _containsValidator(uint64[] memory validatorIds, uint256 count, uint64 validatorId)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < count; ++i) {
            if (validatorIds[i] == validatorId) {
                return true;
            }
        }

        return false;
    }

    function _processValidator(
        address delegator,
        uint64 validatorId,
        uint64 currentEpoch,
        Delegation[] memory positions,
        uint256 positionCount
    ) internal returns (uint256 newPositionCount) {
        DelegatorSnapshot memory snap = _readDelegator(delegator, validatorId);
        uint8 lastWithdrawId;
        bool hasWithdrawals;
        (positionCount, lastWithdrawId, hasWithdrawals) =
            _appendWithdrawals(delegator, validatorId, currentEpoch, positions, positionCount);

        if (snap.stake == 0 && snap.pendingStake == 0 && snap.rewards == 0 && !hasWithdrawals) {
            return positionCount;
        }

        if ((snap.stake > 0 || snap.rewards > 0) && positionCount < MAX_POSITIONS) {
            positions[positionCount] = Delegation({
                validatorId: validatorId,
                withdrawId: lastWithdrawId,
                state: DelegationState.Active,
                amount: snap.stake,
                rewards: snap.rewards,
                withdrawEpoch: 0,
                completionTimestamp: 0
            });
            ++positionCount;
        }

        if (snap.pendingStake > 0 && positionCount < MAX_POSITIONS) {
            positions[positionCount] = Delegation({
                validatorId: validatorId,
                withdrawId: lastWithdrawId,
                state: DelegationState.Activating,
                amount: snap.pendingStake,
                rewards: 0,
                withdrawEpoch: 0,
                completionTimestamp: 0
            });
            ++positionCount;
        }

        return positionCount;
    }

    function _readDelegator(address delegator, uint64 validatorId) internal returns (DelegatorSnapshot memory snap) {
        uint256 deltaStake;
        uint256 nextDeltaStake;
        (snap.stake,, snap.rewards, deltaStake, nextDeltaStake,,) = STAKING.getDelegator(validatorId, delegator);
        snap.pendingStake = deltaStake + nextDeltaStake;
    }

    function _appendWithdrawals(
        address delegator,
        uint64 validatorId,
        uint64 currentEpoch,
        Delegation[] memory positions,
        uint256 positionCount
    ) internal returns (uint256 newPositionCount, uint8 lastWithdrawId, bool hasWithdrawals) {
        uint256 count = positionCount;

        for (uint8 withdrawId = 0; withdrawId < MAX_WITHDRAW_IDS && count < MAX_POSITIONS; ++withdrawId) {
            (uint256 amount,, uint64 withdrawEpoch) = STAKING.getWithdrawalRequest(validatorId, delegator, withdrawId);
            if (amount == 0) {
                continue;
            }

            positions[count] = Delegation({
                validatorId: validatorId,
                withdrawId: withdrawId,
                state: withdrawEpoch < currentEpoch ? DelegationState.AwaitingWithdrawal : DelegationState.Deactivating,
                amount: amount,
                rewards: 0,
                withdrawEpoch: withdrawEpoch,
                completionTimestamp: withdrawEpoch < currentEpoch
                    ? 0
                    : _withdrawCompletionTimestamp(withdrawEpoch, currentEpoch)
            });

            ++count;
            lastWithdrawId = withdrawId;
            hasWithdrawals = true;
        }

        return (count, lastWithdrawId, hasWithdrawals);
    }

    function _withdrawCompletionTimestamp(uint64 withdrawEpoch, uint64 currentEpoch) internal view returns (uint64) {
        if (withdrawEpoch < currentEpoch) {
            return 0;
        }

        uint64 remainingEpochs = withdrawEpoch - currentEpoch + 1;
        uint256 completion = block.timestamp + uint256(remainingEpochs) * uint256(MONAD_EPOCH_SECONDS);
        // casting to uint64 is safe because completion timestamps are bounded by the type max guard above
        // forge-lint: disable-next-line(unsafe-typecast)
        return completion > type(uint64).max ? type(uint64).max : uint64(completion);
    }

    /**
     * @notice Return validator stats plus APY for a set of validator ids.
     * @param validatorIds If empty, uses the full Monad validator set.
     */
    function getValidators(uint64[] calldata validatorIds)
        external
        returns (ValidatorInfo[] memory validators, uint64 networkApyBps)
    {
        uint64[] memory allValidatorIds = _allValidatorIds();
        uint64[] memory targetIds = validatorIds.length == 0 ? allValidatorIds : validatorIds;

        (ValidatorData[] memory data, uint256 totalStake) = _fetchValidators(allValidatorIds);
        networkApyBps = _calculateNetworkApyBps(totalStake);

        validators = new ValidatorInfo[](targetIds.length);
        for (uint256 i = 0; i < targetIds.length; ++i) {
            (ValidatorData memory snapshot, bool found) = _findValidator(data, targetIds[i]);
            if (!found) {
                snapshot.validatorId = targetIds[i];
            }

            uint64 validatorApy = _validatorApyBps(snapshot.stake, totalStake, snapshot.commission, networkApyBps);

            validators[i] = ValidatorInfo({
                validatorId: snapshot.validatorId,
                stake: snapshot.stake,
                commission: snapshot.commission,
                apyBps: validatorApy,
                isActive: found && snapshot.flags == 0 && snapshot.stake > 0
            });
        }
    }

    /**
     * @notice Return APYs for a set of validator ids. Defaults to the full validator set when empty.
     */
    // forge-lint: disable-next-line(mixed-case-function)
    function getAPYs(uint64[] calldata validatorIds) external returns (uint64[] memory apysBps) {
        uint64[] memory allValidatorIds = _allValidatorIds();
        uint64[] memory targetIds = validatorIds.length == 0 ? allValidatorIds : validatorIds;

        (ValidatorData[] memory data, uint256 totalStake) = _fetchValidators(allValidatorIds);
        uint64 networkApyBps = _calculateNetworkApyBps(totalStake);

        apysBps = new uint64[](targetIds.length);
        for (uint256 i = 0; i < targetIds.length; ++i) {
            (ValidatorData memory snapshot, bool found) = _findValidator(data, targetIds[i]);
            if (!found) {
                continue;
            }

            uint64 validatorApy = _validatorApyBps(snapshot.stake, totalStake, snapshot.commission, networkApyBps);
            apysBps[i] = validatorApy;
        }
    }

    function _allValidatorIds() internal returns (uint64[] memory validatorIds) {
        validatorIds = new uint64[](ACTIVE_VALIDATOR_SET);

        uint256 count = 0;
        bool isDone;
        uint32 nextIndex;
        uint64[] memory page;

        (isDone, nextIndex, page) = STAKING.getConsensusValidatorSet(0);
        while (true) {
            uint256 len = page.length;
            for (uint256 i = 0; i < len && count < ACTIVE_VALIDATOR_SET; ++i) {
                validatorIds[count] = page[i];
                ++count;
            }

            if (isDone || count == ACTIVE_VALIDATOR_SET) {
                break;
            }

            (isDone, nextIndex, page) = STAKING.getConsensusValidatorSet(nextIndex);
        }

        if (count == 0) {
            for (uint64 id = 1; id <= ACTIVE_VALIDATOR_SET; ++id) {
                validatorIds[count] = id;
                ++count;
            }
        }

        assembly {
            mstore(validatorIds, count)
        }
    }

    function _fetchValidators(uint64[] memory validatorIds)
        internal
        returns (ValidatorData[] memory validators, uint256 totalStake)
    {
        uint256 len = validatorIds.length;
        validators = new ValidatorData[](len);

        for (uint256 i = 0; i < len; ++i) {
            (, uint64 flags, uint256 stake,, uint256 commission,,,,,,,) = STAKING.getValidator(validatorIds[i]);

            validators[i] =
                ValidatorData({validatorId: validatorIds[i], flags: flags, stake: stake, commission: commission});

            totalStake += stake;
        }
    }

    function _findValidator(ValidatorData[] memory validators, uint64 validatorId)
        internal
        pure
        returns (ValidatorData memory validator, bool found)
    {
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; ++i) {
            if (validators[i].validatorId == validatorId) {
                return (validators[i], true);
            }
        }

        return (validator, false);
    }

    function _calculateNetworkApyBps(uint256 totalStake) internal pure returns (uint64) {
        if (totalStake == 0) {
            return 0;
        }

        uint256 annualRewards = MONAD_BLOCK_REWARD * MONAD_BLOCKS_PER_YEAR;
        // casting to uint64 is safe because APY basis points derived from network totals fit in 64 bits
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64((annualRewards * APY_BPS_PRECISION) / totalStake);
    }

    function _validatorApyBps(uint256 validatorStake, uint256 totalStake, uint256 commission, uint64 networkApyBps)
        internal
        pure
        returns (uint64)
    {
        if (validatorStake == 0 || totalStake == 0) {
            return networkApyBps;
        }

        uint256 stakeWeight = (validatorStake * MONAD_SCALE) / totalStake;
        uint256 expectedBlocks = (stakeWeight * MONAD_BLOCKS_PER_YEAR) / MONAD_SCALE;
        uint256 grossRewards = expectedBlocks * MONAD_BLOCK_REWARD;
        uint256 commissionCut = commission > MONAD_SCALE ? MONAD_SCALE : commission;
        uint256 netRewards = (grossRewards * (MONAD_SCALE - commissionCut)) / MONAD_SCALE;

        uint256 apyBps = (netRewards * APY_BPS_PRECISION) / validatorStake;
        // casting to uint64 is safe because APY basis points are capped by uint64 max guard above
        // forge-lint: disable-next-line(unsafe-typecast)
        return apyBps > type(uint64).max ? type(uint64).max : uint64(apyBps);
    }
}
