// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStakeCredit {
    struct UnbondRequest {
        uint256 shares;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    function balanceOf(address account) external view returns (uint256);

    function getPooledBNBByShares(
        uint256 shares
    ) external view returns (uint256);

    function pendingUnbondRequest(
        address delegator
    ) external view returns (uint256);

    function unbondRequest(
        address delegator,
        uint256 _index
    ) external view returns (UnbondRequest memory);
}
