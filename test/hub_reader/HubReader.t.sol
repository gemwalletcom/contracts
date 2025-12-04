// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {HubReader, Validator, Delegation, Undelegation} from "../../src/hub_reader/HubReader.sol";

contract ValidatorsTest is Test {
    HubReader public reader;

    function setUp() public {
        reader = new HubReader();
    }

    function test_getValidators() public view {
        uint16 limit = 10;
        Validator[] memory validators = reader.getValidators(0, limit);
        assertTrue(validators.length <= limit);

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
        Delegation[] memory delegations = reader.getDelegations(delegator, 0, 10);
        uint256 length = 2;
        assertEq(delegations.length, length);
        assertEq(delegations[length - 1].delegatorAddress, delegator);
        assertEq(delegations[length - 1].validatorAddress, 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A);
        assertTrue(delegations[length - 1].amount > 0);
        assertTrue(delegations[length - 1].shares > 0);
    }

    function test_getUndelegations() public view {
        address delegator = 0xee448667ffc3D15ca023A6deEf2D0fAf084C0716;
        Undelegation[] memory undelegations = reader.getUndelegations(delegator, 0, 10);
        uint256 length = 1;
        assertEq(undelegations.length, length);
        assertEq(undelegations[length - 1].delegatorAddress, delegator);
        assertEq(undelegations[length - 1].validatorAddress, 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A);
        assertTrue(undelegations[length - 1].amount > 0);
        assertTrue(undelegations[length - 1].shares > 0);
        assertTrue(undelegations[length - 1].unlockTime > 0);
    }

    function test_getAPY() public view {
        uint256 timestamp = 1715477981;
        address[] memory operatorAddrs = new address[](3);
        operatorAddrs[0] = address(0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A);
        operatorAddrs[1] = address(0xF2B1d86DC7459887B1f7Ce8d840db1D87613Ce7f);
        operatorAddrs[2] = address(0x773760b0708a5Cc369c346993a0c225D8e4043B1);

        uint64[] memory apys = reader.getAPYs(operatorAddrs, timestamp);

        assertEq(apys[0], 193);
        assertEq(apys[1], 331);
        assertEq(apys[2], 287);
    }
}
