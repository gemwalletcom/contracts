// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IStaking {
    function getConsensusValidatorSet(uint32 startIndex)
        external
        returns (bool isDone, uint32 nextIndex, uint64[] memory valIds);

    function getWithdrawalRequest(uint64 validatorId, address delegator, uint8 withdrawId)
        external
        returns (uint256 withdrawalAmount, uint256 accRewardPerToken, uint64 withdrawEpoch);

    function getEpoch() external returns (uint64 epoch, bool inEpochDelayPeriod);

    function getValidator(uint64 validatorId)
        external
        returns (
            address authAddress,
            uint64 flags,
            uint256 stake,
            uint256 accRewardPerToken,
            uint256 commission,
            uint256 unclaimedRewards,
            uint256 consensusStake,
            uint256 consensusCommission,
            uint256 snapshotStake,
            uint256 snapshotCommission,
            bytes memory secpPubkey,
            bytes memory blsPubkey
        );

    function getDelegations(address delegator, uint64 startValId)
        external
        returns (bool isDone, uint64 nextValId, uint64[] memory valIds);

    function getDelegator(uint64 validatorId, address delegator)
        external
        returns (
            uint256 stake,
            uint256 accRewardPerToken,
            uint256 unclaimedRewards,
            uint256 deltaStake,
            uint256 nextDeltaStake,
            uint64 deltaEpoch,
            uint64 nextDeltaEpoch
        );
}
