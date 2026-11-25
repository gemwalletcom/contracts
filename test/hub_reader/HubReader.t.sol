// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {HubReader, Validator, Delegation, Undelegation} from "../../src/hub_reader/HubReader.sol";

// Fork tests against BNB Smart Chain mainnet (chain id 56) at the latest block.
// They read BSC_RPC_URL and are skipped when it is unset.
contract HubReaderTest is Test {
    uint16 private constant LIMIT = 10;
    uint64 private constant MAX_COMMISSION_BPS = 10_000;

    HubReader private reader;

    function setUp() public {
        string memory rpcUrl = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true);
        }

        vm.createSelectFork(rpcUrl);
        assertEq(block.chainid, 56, "BSC_RPC_URL must point at BNB Smart Chain mainnet");
        reader = new HubReader();
    }

    function test_getValidators() public view {
        Validator[] memory validators = reader.getValidators(0, LIMIT);

        assertEq(validators.length, LIMIT, "validator page length");
        for (uint256 i = 0; i < validators.length; i++) {
            assertTrue(validators[i].operatorAddress != address(0), "operator address");
            assertGt(bytes(validators[i].moniker).length, 0, "moniker");
            assertLe(validators[i].commission, MAX_COMMISSION_BPS, "commission");
        }
    }

    function test_getDelegationsIncludesValidatorSelfDelegation() public view {
        address operator = reader.getValidators(0, 1)[0].operatorAddress;

        Delegation[] memory delegations = reader.getDelegations(operator, 0, LIMIT);

        bool found;
        for (uint256 i = 0; i < delegations.length; i++) {
            assertEq(delegations[i].delegatorAddress, operator, "delegator address");
            assertGt(delegations[i].amount, 0, "amount");
            assertGt(delegations[i].shares, 0, "shares");
            if (delegations[i].validatorAddress == operator) {
                found = true;
            }
        }
        assertTrue(found, "self delegation");
    }

    function test_getDelegationsEmptyForUnknownDelegator() public {
        Delegation[] memory delegations = reader.getDelegations(makeAddr("no positions"), 0, LIMIT);

        assertEq(delegations.length, 0, "delegation count");
    }

    function test_getUndelegationsEmptyForUnknownDelegator() public {
        Undelegation[] memory undelegations = reader.getUndelegations(makeAddr("no positions"), 0, LIMIT);

        assertEq(undelegations.length, 0, "undelegation count");
    }

    function test_getAPYs() public view {
        uint256 timestamp = 1715477981;
        address[] memory operatorAddrs = new address[](3);
        operatorAddrs[0] = address(0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A);
        operatorAddrs[1] = address(0xF2B1d86DC7459887B1f7Ce8d840db1D87613Ce7f);
        operatorAddrs[2] = address(0x773760b0708a5Cc369c346993a0c225D8e4043B1);

        uint64[] memory apys = reader.getAPYs(operatorAddrs, timestamp);

        assertEq(apys[0], 193, "first validator APY");
        assertEq(apys[1], 331, "second validator APY");
        assertEq(apys[2], 287, "third validator APY");
    }
}
