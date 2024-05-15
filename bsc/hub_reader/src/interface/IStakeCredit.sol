// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStakeCredit {
    function balanceOf(address account) external view returns (uint256);

    function getPooledBNBByShares(
        uint256 shares
    ) external view returns (uint256);
}
