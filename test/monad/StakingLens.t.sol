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

    function _mockConsensusSet() internal {
        bytes memory data = abi.encodeCall(IStaking.getConsensusValidatorSet, (0));
        bytes memory result = abi.encode(true, uint32(0), validatorIds);
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

    function _expectedNetworkApy() internal view returns (uint64) {
        uint256 annualRewards = lens.MONAD_BLOCK_REWARD() * lens.MONAD_BLOCKS_PER_YEAR();
        uint256 apy = (annualRewards * lens.APY_BPS_PRECISION()) / TOTAL_STAKE;
        // casting to uint64 is safe because APY basis points are intentionally capped within uint64 range
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(apy);
    }
}
