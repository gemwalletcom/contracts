// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {StakingLens} from "../../src/monad/StakingLens.sol";
import {IStaking} from "../../src/monad/IStaking.sol";

contract StakingLensTest is Test {
    StakingLens private lens;
    address private constant STAKING_PRECOMPILE = address(0x0000000000000000000000000000000000001000);
    uint64 private constant MONADVISION_VALIDATOR_ID = 16;
    uint64 private constant ALCHEMY_VALIDATOR_ID = 5;
    uint64 private constant STAKIN_VALIDATOR_ID = 10;
    uint64 private constant EVERSTAKE_VALIDATOR_ID = 9;

    uint64[] private validatorIds;
    uint256 private constant TOTAL_STAKE = 1e30;
    uint256 private constant VALIDATOR_STAKE = TOTAL_STAKE / 2;

    function setUp() public {
        lens = new StakingLens();

        validatorIds = new uint64[](2);
        validatorIds[0] = 1;
        validatorIds[1] = 2;

        _mockConsensusSet();
        _mockValidator(validatorIds[0], VALIDATOR_STAKE, 0);
        _mockValidator(validatorIds[1], VALIDATOR_STAKE, 0);
    }

    function test_getAPYsUsesAllValidatorsWhenEmpty() public {
        uint64[] memory apys = lens.getAPYs(new uint64[](0));

        uint64 expected = _expectedNetworkApy();
        assertEq(apys.length, validatorIds.length);
        assertEq(apys[0], expected);
        assertEq(apys[1], expected);
    }

    function test_getValidatorsReturnsNetworkApy() public {
        (StakingLens.ValidatorInfo[] memory validators, uint64 networkApy) = lens.getValidators(new uint64[](0));

        uint64 expected = _expectedNetworkApy();
        assertEq(networkApy, expected);
        assertEq(validators.length, validatorIds.length);
        assertEq(validators[0].validatorId, validatorIds[0]);
        assertEq(validators[0].apyBps, expected);
        assertEq(validators[1].validatorId, validatorIds[1]);
        assertEq(validators[1].apyBps, expected);
    }

    function test_getDelegationsIncludesPositionsWithoutActiveDelegations() public {
        address delegator = address(0xc08A759F868Ab179F1259b2A7b1B81b0B968710E);
        uint64 withdrawValidatorId = 7;
        uint64 rewardsValidatorId = 9;
        uint64 currentEpoch = 3;
        uint64 withdrawEpoch = 4;
        uint256 withdrawAmount = 2 ether;
        uint256 rewardAmount = 1 ether;

        uint64[] memory validators = new uint64[](2);
        validators[0] = withdrawValidatorId;
        validators[1] = rewardsValidatorId;
        _mockConsensusSet(validators);

        _mockEpoch(currentEpoch);
        _mockDelegations(delegator, new uint64[](0));
        _mockKnownValidators(delegator);
        _mockDelegator(delegator, withdrawValidatorId, 0, 0, 0, 0);
        _mockDelegator(delegator, rewardsValidatorId, 0, rewardAmount, 0, 0);

        _mockWithdrawalRequests(
            withdrawValidatorId, delegator, 0, withdrawAmount, withdrawEpoch, lens.MAX_WITHDRAW_IDS()
        );

        StakingLens.Delegation[] memory positions = lens.getDelegations(delegator);

        assertEq(positions.length, 2);

        bool foundWithdraw;
        bool foundRewards;
        for (uint256 i = 0; i < positions.length; ++i) {
            StakingLens.Delegation memory position = positions[i];

            if (
                position.validatorId == withdrawValidatorId
                    && position.state == StakingLens.DelegationState.Deactivating
            ) {
                foundWithdraw = true;
                assertEq(position.withdrawId, 0);
                assertEq(position.amount, withdrawAmount);
                assertEq(position.rewards, 0);
                assertEq(position.withdrawEpoch, withdrawEpoch);
                assertGt(position.completionTimestamp, 0);
            }

            if (position.validatorId == rewardsValidatorId && position.state == StakingLens.DelegationState.Active) {
                foundRewards = true;
                assertEq(position.amount, 0);
                assertEq(position.rewards, rewardAmount);
                assertEq(position.withdrawEpoch, 0);
                assertEq(position.completionTimestamp, 0);
            }
        }

        assertTrue(foundWithdraw);
        assertTrue(foundRewards);
    }

    function test_getDelegationsIncludesWithdrawalsWhenActiveDelegationsExist() public {
        address delegator = address(0xc08A759F868Ab179F1259b2A7b1B81b0B968710E);
        uint64 withdrawValidatorId = 7;
        uint64 activeValidatorId = 9;
        uint64 currentEpoch = 3;
        uint64 withdrawEpoch = 4;
        uint256 withdrawAmount = 2 ether;
        uint256 activeStake = 5 ether;

        uint64[] memory validators = new uint64[](2);
        validators[0] = withdrawValidatorId;
        validators[1] = activeValidatorId;
        _mockConsensusSet(validators);

        uint64[] memory activeDelegations = new uint64[](1);
        activeDelegations[0] = activeValidatorId;

        _mockEpoch(currentEpoch);
        _mockDelegations(delegator, activeDelegations);
        _mockKnownValidators(delegator);
        _mockDelegator(delegator, activeValidatorId, activeStake, 0, 0, 0);
        _mockDelegator(delegator, withdrawValidatorId, 0, 0, 0, 0);

        _mockWithdrawalRequests(
            withdrawValidatorId, delegator, 1, withdrawAmount, withdrawEpoch, lens.MAX_WITHDRAW_IDS()
        );

        StakingLens.Delegation[] memory positions = lens.getDelegations(delegator);

        assertEq(positions.length, 2);

        bool foundActive;
        bool foundWithdraw;
        for (uint256 i = 0; i < positions.length; ++i) {
            StakingLens.Delegation memory position = positions[i];

            if (position.validatorId == activeValidatorId && position.state == StakingLens.DelegationState.Active) {
                foundActive = true;
                assertEq(position.amount, activeStake);
                assertEq(position.rewards, 0);
            }

            if (
                position.validatorId == withdrawValidatorId
                    && position.state == StakingLens.DelegationState.Deactivating && position.withdrawId == 1
            ) {
                foundWithdraw = true;
                assertEq(position.amount, withdrawAmount);
                assertEq(position.rewards, 0);
                assertEq(position.withdrawEpoch, withdrawEpoch);
            }
        }

        assertTrue(foundActive);
        assertTrue(foundWithdraw);
    }

    function test_getDelegationsFullScansActiveValidatorsBeyondShallowScanRange() public {
        address delegator = address(0xc08A759F868Ab179F1259b2A7b1B81b0B968710E);
        uint64 activeValidatorId = 42;
        uint64 currentEpoch = 3;
        uint64 withdrawEpoch = 4;
        uint8 highWithdrawId = 42;
        uint256 activeStake = 5 ether;
        uint256 withdrawAmount = 2 ether;

        uint64[] memory validators = new uint64[](1);
        validators[0] = activeValidatorId;
        _mockConsensusSet(validators);

        uint64[] memory activeDelegations = new uint64[](1);
        activeDelegations[0] = activeValidatorId;

        _mockEpoch(currentEpoch);
        _mockDelegations(delegator, activeDelegations);
        _mockKnownValidators(delegator);
        _mockDelegator(delegator, activeValidatorId, activeStake, 0, 0, 0);
        _mockWithdrawalRequests(
            activeValidatorId, delegator, highWithdrawId, withdrawAmount, withdrawEpoch, lens.FULL_SCAN_WITHDRAW_IDS()
        );

        StakingLens.Delegation[] memory positions = lens.getDelegations(delegator);

        assertEq(positions.length, 2);

        bool foundActive;
        bool foundWithdraw;
        for (uint256 i = 0; i < positions.length; ++i) {
            StakingLens.Delegation memory position = positions[i];

            if (position.validatorId == activeValidatorId && position.state == StakingLens.DelegationState.Active) {
                foundActive = true;
                assertEq(position.amount, activeStake);
            }

            if (
                position.validatorId == activeValidatorId && position.state == StakingLens.DelegationState.Deactivating
                    && position.withdrawId == highWithdrawId
            ) {
                foundWithdraw = true;
                assertEq(position.amount, withdrawAmount);
                assertEq(position.withdrawEpoch, withdrawEpoch);
            }
        }

        assertTrue(foundActive);
        assertTrue(foundWithdraw);
    }

    function test_getDelegationsFullScansCuratedValidatorsBeyondShallowScanRange() public {
        address delegator = address(0xc08A759F868Ab179F1259b2A7b1B81b0B968710E);
        uint64 currentEpoch = 3;
        uint64 withdrawEpoch = 4;
        uint8 highWithdrawId = 42;
        uint256 withdrawAmount = 2 ether;
        uint64[] memory curatedValidatorIds = _curatedValidatorIds();

        _mockConsensusSet(curatedValidatorIds);

        _mockEpoch(currentEpoch);
        _mockDelegations(delegator, new uint64[](0));
        _mockKnownValidators(delegator);

        for (uint256 i = 0; i < curatedValidatorIds.length; ++i) {
            _mockWithdrawalRequests(
                curatedValidatorIds[i],
                delegator,
                highWithdrawId,
                withdrawAmount,
                withdrawEpoch,
                lens.FULL_SCAN_WITHDRAW_IDS()
            );
        }

        StakingLens.Delegation[] memory positions = lens.getDelegations(delegator);

        assertEq(positions.length, curatedValidatorIds.length);

        for (uint256 i = 0; i < curatedValidatorIds.length; ++i) {
            bool foundValidator;

            for (uint256 j = 0; j < positions.length; ++j) {
                StakingLens.Delegation memory position = positions[j];
                if (position.validatorId != curatedValidatorIds[i]) {
                    continue;
                }

                foundValidator = true;
                assertEq(position.withdrawId, highWithdrawId);
                assertEq(uint8(position.state), uint8(StakingLens.DelegationState.Deactivating));
                assertEq(position.amount, withdrawAmount);
                assertEq(position.withdrawEpoch, withdrawEpoch);
                break;
            }

            assertTrue(foundValidator);
        }
    }

    function test_getDelegationsPrioritizesCuratedValidatorsBeforeActiveDelegationCap() public {
        address delegator = address(0xc08A759F868Ab179F1259b2A7b1B81b0B968710E);
        uint64 currentEpoch = 3;
        uint64 withdrawEpoch = 4;
        uint8 highWithdrawId = 42;
        uint256 withdrawAmount = 2 ether;
        uint64[] memory activeDelegations = _sequentialValidatorIds(100, lens.MAX_DELEGATIONS());

        _mockConsensusSet(activeDelegations);
        _mockEpoch(currentEpoch);
        _mockDelegations(delegator, activeDelegations);
        _mockKnownValidators(delegator);
        _mockEmptyValidators(delegator, activeDelegations, lens.FULL_SCAN_WITHDRAW_IDS());
        _mockWithdrawalRequests(
            EVERSTAKE_VALIDATOR_ID,
            delegator,
            highWithdrawId,
            withdrawAmount,
            withdrawEpoch,
            lens.FULL_SCAN_WITHDRAW_IDS()
        );

        StakingLens.Delegation[] memory positions = lens.getDelegations(delegator);

        assertEq(positions.length, 1);
        assertEq(positions[0].validatorId, EVERSTAKE_VALIDATOR_ID);
        assertEq(positions[0].withdrawId, highWithdrawId);
        assertEq(uint8(positions[0].state), uint8(StakingLens.DelegationState.Deactivating));
        assertEq(positions[0].amount, withdrawAmount);
        assertEq(positions[0].withdrawEpoch, withdrawEpoch);
    }

    function _mockConsensusSet() internal {
        _mockConsensusSet(validatorIds);
    }

    function _mockConsensusSet(uint64[] memory ids) internal {
        bytes memory data = abi.encodeCall(IStaking.getConsensusValidatorSet, (0));
        bytes memory result = abi.encode(true, uint32(0), ids);
        vm.mockCall(STAKING_PRECOMPILE, data, result);
    }

    function _mockValidator(uint64 validatorId, uint256 stake, uint256 commission) internal {
        bytes memory data = abi.encodeCall(IStaking.getValidator, (validatorId));
        bytes memory result = abi.encode(
            address(0),
            uint64(0),
            stake,
            uint256(0),
            commission,
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0),
            bytes(""),
            bytes("")
        );
        vm.mockCall(STAKING_PRECOMPILE, data, result);
    }

    function _mockEpoch(uint64 epoch) internal {
        bytes memory data = abi.encodeCall(IStaking.getEpoch, ());
        bytes memory result = abi.encode(epoch, false);
        vm.mockCall(STAKING_PRECOMPILE, data, result);
    }

    function _mockDelegations(address delegator, uint64[] memory valIds) internal {
        bytes memory data = abi.encodeCall(IStaking.getDelegations, (delegator, uint64(0)));
        bytes memory result = abi.encode(true, uint64(0), valIds);
        vm.mockCall(STAKING_PRECOMPILE, data, result);
    }

    function _mockDelegator(
        address delegator,
        uint64 validatorId,
        uint256 stake,
        uint256 rewards,
        uint256 deltaStake,
        uint256 nextDeltaStake
    ) internal {
        bytes memory data = abi.encodeCall(IStaking.getDelegator, (validatorId, delegator));
        bytes memory result = abi.encode(stake, uint256(0), rewards, deltaStake, nextDeltaStake, uint64(0), uint64(0));
        vm.mockCall(STAKING_PRECOMPILE, data, result);
    }

    function _mockWithdrawalRequest(
        uint64 validatorId,
        address delegator,
        uint8 withdrawId,
        uint256 amount,
        uint64 withdrawEpoch
    ) internal {
        bytes memory data = abi.encodeCall(IStaking.getWithdrawalRequest, (validatorId, delegator, withdrawId));
        bytes memory result = abi.encode(amount, uint256(0), withdrawEpoch);
        vm.mockCall(STAKING_PRECOMPILE, data, result);
    }

    function _mockWithdrawalRequests(
        uint64 validatorId,
        address delegator,
        uint8 nonZeroWithdrawId,
        uint256 amount,
        uint64 withdrawEpoch,
        uint16 scanLimit
    ) internal {
        for (uint16 withdrawId = 0; withdrawId < scanLimit; ++withdrawId) {
            uint256 requestAmount = withdrawId == nonZeroWithdrawId ? amount : 0;
            uint64 requestEpoch = withdrawId == nonZeroWithdrawId ? withdrawEpoch : 0;
            // casting is safe because the test only passes scan limits within the uint8 withdraw id range
            // forge-lint: disable-next-line(unsafe-typecast)
            _mockWithdrawalRequest(validatorId, delegator, uint8(withdrawId), requestAmount, requestEpoch);
        }
    }

    function _mockKnownValidators(address delegator) internal {
        _mockEmptyValidators(delegator, _curatedValidatorIds(), lens.FULL_SCAN_WITHDRAW_IDS());
    }

    function _mockEmptyValidators(address delegator, uint64[] memory validatorIdsToMock, uint16 scanLimit) internal {
        for (uint256 i = 0; i < validatorIdsToMock.length; ++i) {
            _mockDelegator(delegator, validatorIdsToMock[i], 0, 0, 0, 0);
            _mockWithdrawalRequests(validatorIdsToMock[i], delegator, 0, 0, 0, scanLimit);
        }
    }

    function _curatedValidatorIds() internal pure returns (uint64[] memory ids) {
        ids = new uint64[](4);
        ids[0] = MONADVISION_VALIDATOR_ID;
        ids[1] = ALCHEMY_VALIDATOR_ID;
        ids[2] = STAKIN_VALIDATOR_ID;
        ids[3] = EVERSTAKE_VALIDATOR_ID;
    }

    function _sequentialValidatorIds(uint64 startValidatorId, uint16 count)
        internal
        pure
        returns (uint64[] memory ids)
    {
        ids = new uint64[](uint256(count));

        for (uint16 i = 0; i < count; ++i) {
            ids[i] = startValidatorId + uint64(i);
        }
    }

    function _expectedNetworkApy() internal view returns (uint64) {
        uint256 annualRewards = lens.MONAD_BLOCK_REWARD() * lens.MONAD_BLOCKS_PER_YEAR();
        uint256 apy = (annualRewards * lens.APY_BPS_PRECISION()) / TOTAL_STAKE;
        // casting to uint64 is safe because APY basis points are intentionally capped within uint64 range
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(apy);
    }
}
