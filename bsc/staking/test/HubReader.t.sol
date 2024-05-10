// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {HubReader, Validator, Delegation} from "../src/HubReader.sol";

contract ValidatorsTest is Test {
    HubReader public reader;

    function setUp() public {
        reader = new HubReader();
    }

    function test_getValidators() public view {
        Validator[] memory validators = reader.getValidators(0, 30);
        assertEq(validators.length, 30);

        address operatorAddrs = 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A;
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i].operatorAddress == operatorAddrs) {
                assertEq(validators[i].jailed, false);
                assertEq(validators[i].moniker, "LegendII");
                assertEq(validators[i].commission, 700);

                break;
            }
        }
    }

    function test_getDelegations() public view {
        address delegator = 0xee448667ffc3D15ca023A6deEf2D0fAf084C0716;
        Delegation[] memory delegations = reader.getDelegations(
            delegator,
            0,
            30
        );
        assertEq(delegations.length, 1);
        assertEq(delegations[0].delegatorAddress, delegator);
        assertEq(
            delegations[0].validatorAddress,
            0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A
        );
        assertTrue(delegations[0].amount > 0);
    }
}
