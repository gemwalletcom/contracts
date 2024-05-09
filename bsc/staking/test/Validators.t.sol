// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ValidatorsReader, Validator} from "../src/Validators.sol";

contract ValidatorsTest is Test {
    ValidatorsReader public reader;

    function setUp() public {
        reader = new ValidatorsReader();
    }

    function test_getValidators() public view {
        Validator[] memory validators = reader.getValidators(0, 30);
        assertEq(validators.length, 30);

        address operatorAddrs = 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A;
        address creditAddrs = 0xeC06CB25d9add4bDd67B61432163aFF9028Aa921;
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i].operatorAddress == operatorAddrs) {
                assertEq(validators[i].creditAddress, creditAddrs);
                assertEq(validators[i].jailed, false);
                assertEq(validators[i].jailUntil, 0);
                assertEq(validators[i].moniker, "LegendII");
                assertEq(validators[i].commission, 700);
            }
        }
    }
}
