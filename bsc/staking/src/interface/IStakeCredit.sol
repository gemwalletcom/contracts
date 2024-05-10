// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStakeCredit {
    function getPooledBNB(address account) external view returns (uint256);
}
