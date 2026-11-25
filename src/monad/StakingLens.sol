// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IStaking} from "./IStaking.sol";

contract StakingLens {
    IStaking public constant STAKING = IStaking(0x0000000000000000000000000000000000001000);

    uint8 public constant MAX_FALLBACK_SCAN_VALIDATORS = 128;
    uint16 public constant MAX_DELEGATIONS = MAX_FALLBACK_SCAN_VALIDATORS;
    uint8 public constant MAX_WITHDRAW_IDS = 8;
    uint16 public constant FULL_SCAN_WITHDRAW_IDS = 256;
    uint8 public constant MAX_FULL_SCAN_VALIDATORS = 8;
    uint8 internal constant CURATED_VALIDATOR_COUNT = 4;
    uint32 public constant ACTIVE_VALIDATOR_SET = 200;
    uint256 private constant MAX_SCAN_VALIDATORS = uint256(MAX_DELEGATIONS) + CURATED_VALIDATOR_COUNT;
    uint256 public constant MAX_POSITIONS = MAX_SCAN_VALIDATORS * (2 + uint256(MAX_WITHDRAW_IDS))
        + uint256(MAX_FULL_SCAN_VALIDATORS) * (FULL_SCAN_WITHDRAW_IDS - MAX_WITHDRAW_IDS);
    uint64 internal constant MONADVISION_VALIDATOR_ID = 16;
    uint64 internal constant ALCHEMY_VALIDATOR_ID = 5;
    uint64 internal constant STAKIN_VALIDATOR_ID = 10;
    uint64 internal constant EVERSTAKE_VALIDATOR_ID = 9;

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

    struct ValidatorIds {
        uint64[] ids;
        uint256 count;
        uint256 seen;
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
        uint64[CURATED_VALIDATOR_COUNT] memory curated = _curatedValidatorIds();
        uint64 next;
        bool done;
        uint64[] memory ids;
        while (!done) {
            (done, next, ids) = STAKING.getDelegations(delegator, next);
            for (uint256 i = 0; i < ids.length; ++i) {
                uint64 id = ids[i];
                (staked, pending, rewards) = _addDelegatorBalance(delegator, id, staked, pending, rewards);
                for (uint256 j = 0; j < curated.length; ++j) {
                    if (curated[j] == id) {
                        curated[j] = 0;
                    }
                }
            }
        }
        for (uint256 i = 0; i < curated.length; ++i) {
            if (curated[i] != 0) {
                (staked, pending, rewards) = _addDelegatorBalance(delegator, curated[i], staked, pending, rewards);
            }
        }
    }

    function getDelegations(address delegator) external returns (Delegation[] memory positions) {
        (ValidatorIds memory validators, uint256 activeCount, uint256 unlistedCurated) =
            _prioritizedValidators(delegator);
        (uint256 fullScanMask, uint256 fullScanCount) = _fullScanValidators(validators.count, unlistedCurated);
        if (activeCount < MAX_DELEGATIONS) {
            uint256 limit = validators.count + MAX_DELEGATIONS - activeCount;
            uint64[] memory consensus = _allValidatorIds();
            for (uint256 i = 0; i < consensus.length && validators.count < limit; ++i) {
                _appendUniqueValidatorId(validators, consensus[i]);
            }
        }
        // Reserve references only. Every position in the returned prefix is assigned before the array is trimmed.
        bytes32[] memory positionSlots = new bytes32[](
            validators.count * (2 + uint256(MAX_WITHDRAW_IDS)) + fullScanCount
                * (FULL_SCAN_WITHDRAW_IDS - MAX_WITHDRAW_IDS)
        );
        assembly ("memory-safe") {
            positions := positionSlots
        }
        (uint64 currentEpoch,) = STAKING.getEpoch();
        uint256 positionCount = 0;
        for (uint256 i = 0; i < validators.count; ++i) {
            uint16 slots = (fullScanMask >> i) & 1 == 1 ? FULL_SCAN_WITHDRAW_IDS : MAX_WITHDRAW_IDS;
            positionCount =
                _processValidator(delegator, validators.ids[i], currentEpoch, positions, positionCount, slots);
        }
        assembly {
            mstore(positions, positionCount)
        }
    }

    function _prioritizedValidators(address delegator)
        internal
        returns (ValidatorIds memory validators, uint256 activeCount, uint256 unlistedCurated)
    {
        validators.ids = new uint64[](MAX_SCAN_VALIDATORS);
        uint64[CURATED_VALIDATOR_COUNT] memory curated = _curatedValidatorIds();
        for (uint256 i = 0; i < curated.length; ++i) {
            _appendUniqueValidatorId(validators, curated[i]);
        }
        unlistedCurated = (uint256(1) << curated.length) - 1;
        uint64 next;
        bool done;
        uint64[] memory page;
        while (!done && activeCount < MAX_DELEGATIONS) {
            (done, next, page) = STAKING.getDelegations(delegator, next);
            for (uint256 i = 0; i < page.length && activeCount < MAX_DELEGATIONS; ++i) {
                uint256 previousCount = validators.count;
                uint256 index = _appendUniqueValidatorId(validators, page[i]);
                if (index == previousCount) {
                    ++activeCount;
                } else if ((unlistedCurated & (uint256(1) << index)) != 0) {
                    unlistedCurated ^= uint256(1) << index;
                    ++activeCount;
                }
            }
        }
    }

    /// @dev Selects the first MAX_FULL_SCAN_VALIDATORS validators in the delegator's native list, curated ones
    /// first, as a bitmask over validator indexes. A curated validator absent from that list gets the shallow
    /// scan, so a wallet that never staked does not pay for 256 withdrawal lookups on each curated validator.
    function _fullScanValidators(uint256 listedCount, uint256 unlistedCurated)
        internal
        pure
        returns (uint256 mask, uint256 count)
    {
        for (uint256 i = 0; i < listedCount && count < MAX_FULL_SCAN_VALIDATORS; ++i) {
            uint256 bit = uint256(1) << i;
            if ((unlistedCurated & bit) == 0) {
                mask |= bit;
                ++count;
            }
        }
    }

    function _curatedValidatorIds() internal pure returns (uint64[CURATED_VALIDATOR_COUNT] memory validatorIds) {
        validatorIds[0] = MONADVISION_VALIDATOR_ID;
        validatorIds[1] = ALCHEMY_VALIDATOR_ID;
        validatorIds[2] = STAKIN_VALIDATOR_ID;
        validatorIds[3] = EVERSTAKE_VALIDATOR_ID;
    }

    function _appendUniqueValidatorId(ValidatorIds memory validators, uint64 id) internal pure returns (uint256) {
        uint256 bit = uint256(1) << (id & 255);
        if ((validators.seen & bit) != 0) {
            for (uint256 i = 0; i < validators.count; ++i) {
                if (validators.ids[i] == id) return i;
            }
        }
        validators.seen |= bit;
        uint256 index = validators.count++;
        validators.ids[index] = id;
        return index;
    }

    function _processValidator(
        address delegator,
        uint64 validatorId,
        uint64 currentEpoch,
        Delegation[] memory positions,
        uint256 positionCount,
        uint16 maxWithdrawIds
    ) internal returns (uint256 newPositionCount) {
        DelegatorSnapshot memory snap = _readDelegator(delegator, validatorId);
        uint8 lastWithdrawId;
        (positionCount, lastWithdrawId) =
            _appendWithdrawals(delegator, validatorId, currentEpoch, positions, positionCount, maxWithdrawIds);

        if (snap.stake > 0 || snap.rewards > 0) {
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

        if (snap.pendingStake > 0) {
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

    function _addDelegatorBalance(
        address delegator,
        uint64 validatorId,
        uint256 currentStaked,
        uint256 currentPending,
        uint256 currentRewards
    ) internal returns (uint256 staked, uint256 pending, uint256 rewards) {
        DelegatorSnapshot memory snap = _readDelegator(delegator, validatorId);
        return (currentStaked + snap.stake, currentPending + snap.pendingStake, currentRewards + snap.rewards);
    }

    function _appendWithdrawals(
        address delegator,
        uint64 validatorId,
        uint64 currentEpoch,
        Delegation[] memory positions,
        uint256 positionCount,
        uint16 maxWithdrawIds
    ) internal returns (uint256 newPositionCount, uint8 lastWithdrawId) {
        assert(maxWithdrawIds <= uint16(type(uint8).max) + 1);
        uint256 count = positionCount;

        for (uint16 withdrawId = 0; withdrawId < maxWithdrawIds; ++withdrawId) {
            // The maxWithdrawIds assertion keeps withdrawId within the uint8 request-id range.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8 requestWithdrawId = uint8(withdrawId);
            (uint256 amount,, uint64 withdrawEpoch) =
                STAKING.getWithdrawalRequest(validatorId, delegator, requestWithdrawId);
            if (amount == 0) {
                continue;
            }

            positions[count] = Delegation({
                validatorId: validatorId,
                withdrawId: requestWithdrawId,
                state: withdrawEpoch < currentEpoch ? DelegationState.AwaitingWithdrawal : DelegationState.Deactivating,
                amount: amount,
                rewards: 0,
                withdrawEpoch: withdrawEpoch,
                completionTimestamp: withdrawEpoch < currentEpoch
                    ? 0
                    : _withdrawCompletionTimestamp(withdrawEpoch, currentEpoch)
            });

            ++count;
            lastWithdrawId = requestWithdrawId;
        }

        return (count, lastWithdrawId);
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
        uint256 count = validatorIds.length == 0 ? allValidatorIds.length : validatorIds.length;

        (ValidatorData[] memory data, uint256 totalStake) = _fetchValidators(allValidatorIds);
        networkApyBps = _calculateNetworkApyBps(totalStake);

        validators = new ValidatorInfo[](count);
        for (uint256 i = 0; i < count; ++i) {
            (ValidatorData memory snapshot,) = _requestedValidator(data, validatorIds, i);
            uint64 validatorApy = _validatorApyBps(snapshot.stake, totalStake, snapshot.commission, networkApyBps);

            validators[i] = ValidatorInfo({
                validatorId: snapshot.validatorId,
                stake: snapshot.stake,
                commission: snapshot.commission,
                apyBps: validatorApy,
                isActive: snapshot.flags == 0 && snapshot.stake > 0
            });
        }
    }

    /**
     * @notice Return APYs for a set of validator ids. Defaults to the full validator set when empty.
     */
    // forge-lint: disable-next-line(mixed-case-function)
    function getAPYs(uint64[] calldata validatorIds) external returns (uint64[] memory apysBps) {
        uint64[] memory allValidatorIds = _allValidatorIds();
        uint256 count = validatorIds.length == 0 ? allValidatorIds.length : validatorIds.length;

        (ValidatorData[] memory data, uint256 totalStake) = _fetchValidators(allValidatorIds);
        uint64 networkApyBps = _calculateNetworkApyBps(totalStake);

        apysBps = new uint64[](count);
        for (uint256 i = 0; i < count; ++i) {
            (ValidatorData memory snapshot, bool found) = _requestedValidator(data, validatorIds, i);
            if (!found) continue;
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

    function _requestedValidator(ValidatorData[] memory validators, uint64[] calldata requested, uint256 index)
        internal
        pure
        returns (ValidatorData memory result, bool found)
    {
        if (requested.length == 0) return (validators[index], true);
        uint64 id = requested[index];
        for (uint256 i = 0; i < validators.length; ++i) {
            if (validators[i].validatorId == id) return (validators[i], true);
        }
        result.validatorId = id;
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
