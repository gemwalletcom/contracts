// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {StakingLens} from "../../src/monad/StakingLens.sol";
import {IStaking} from "../../src/monad/IStaking.sol";

contract StakingLensTest is Test {
    StakingLens private lens;
    address private constant STAKING_PRECOMPILE = address(0x0000000000000000000000000000000000001000);

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
        _mockDelegator(delegator, withdrawValidatorId, 0, 0, 0, 0);
        _mockDelegator(delegator, rewardsValidatorId, 0, rewardAmount, 0, 0);

        _mockWithdrawalRequest(withdrawValidatorId, delegator, 0, withdrawAmount, withdrawEpoch);
        for (uint8 withdrawId = 1; withdrawId < lens.MAX_WITHDRAW_IDS(); ++withdrawId) {
            _mockWithdrawalRequest(withdrawValidatorId, delegator, withdrawId, 0, 0);
        }
        for (uint8 withdrawId = 0; withdrawId < lens.MAX_WITHDRAW_IDS(); ++withdrawId) {
            _mockWithdrawalRequest(rewardsValidatorId, delegator, withdrawId, 0, 0);
        }

        StakingLens.Delegation[] memory positions = lens.getDelegations(delegator);

        assertEq(positions.length, 2);

        assertEq(positions[0].validatorId, withdrawValidatorId);
        assertEq(positions[0].withdrawId, 0);
        assertEq(uint8(positions[0].state), uint8(StakingLens.DelegationState.Deactivating));
        assertEq(positions[0].amount, withdrawAmount);
        assertEq(positions[0].rewards, 0);
        assertEq(positions[0].withdrawEpoch, withdrawEpoch);
        assertGt(positions[0].completionTimestamp, 0);

        assertEq(positions[1].validatorId, rewardsValidatorId);
        assertEq(uint8(positions[1].state), uint8(StakingLens.DelegationState.Active));
        assertEq(positions[1].amount, 0);
        assertEq(positions[1].rewards, rewardAmount);
        assertEq(positions[1].withdrawEpoch, 0);
        assertEq(positions[1].completionTimestamp, 0);
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
        _mockDelegator(delegator, activeValidatorId, activeStake, 0, 0, 0);
        _mockDelegator(delegator, withdrawValidatorId, 0, 0, 0, 0);

        for (uint8 withdrawId = 0; withdrawId < lens.MAX_WITHDRAW_IDS(); ++withdrawId) {
            _mockWithdrawalRequest(activeValidatorId, delegator, withdrawId, 0, 0);
        }
        _mockWithdrawalRequest(withdrawValidatorId, delegator, 1, withdrawAmount, withdrawEpoch);
        for (uint8 withdrawId = 0; withdrawId < lens.MAX_WITHDRAW_IDS(); ++withdrawId) {
            if (withdrawId != 1) {
                _mockWithdrawalRequest(withdrawValidatorId, delegator, withdrawId, 0, 0);
            }
        }

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

    function _mockConsensusSet() internal {
        bytes memory data = abi.encodeCall(IStaking.getConsensusValidatorSet, (0));
        bytes memory result = abi.encode(true, uint32(0), validatorIds);
        vm.mockCall(STAKING_PRECOMPILE, data, result);
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

    function _expectedNetworkApy() internal view returns (uint64) {
        uint256 annualRewards = lens.MONAD_BLOCK_REWARD() * lens.MONAD_BLOCKS_PER_YEAR();
        uint256 apy = (annualRewards * lens.APY_BPS_PRECISION()) / TOTAL_STAKE;
        // casting to uint64 is safe because APY basis points are intentionally capped within uint64 range
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(apy);
    }
}
