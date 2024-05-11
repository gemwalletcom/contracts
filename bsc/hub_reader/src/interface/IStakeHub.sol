// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Description {
    string moniker;
    string identity;
    string website;
    string details;
}

struct Commission {
    uint64 rate; // the commission rate charged to delegators(10000 is 100%)
    uint64 maxRate; // maximum commission rate which validator can ever charge
    uint64 maxChangeRate; // maximum daily increase of the validator commission
}

interface IStakeHub {
    function getValidators(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (
            address[] memory operatorAddrs,
            address[] memory creditAddrs,
            uint256 totalLength
        );

    function getValidatorBasicInfo(
        address operatorAddress
    )
        external
        view
        returns (uint256 createdTime, bool jailed, uint256 jailUntil);

    function getValidatorDescription(
        address operatorAddress
    ) external view returns (Description memory);

    function getValidatorCommission(
        address operatorAddress
    ) external view returns (Commission memory);

    function getValidatorRewardRecord(
        address operatorAddress,
        uint256 index
    ) external view returns (uint256);

    function getValidatorTotalPooledBNBRecord(
        address operatorAddress,
        uint256 index
    ) external view returns (uint256);
}
