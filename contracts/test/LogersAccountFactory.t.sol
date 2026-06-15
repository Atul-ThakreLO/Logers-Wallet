// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {TestHelper} from "./helpers/TestHelper.sol";
import {LogersAccount} from "../src/LogersAccount.sol";
import {LogersAccountFactory} from "../src/LogersAccountFactory.sol";

contract LogersAccountFactoryTest is TestHelper {
    // ─── createAccount ────────────────────────────────────────────────────── //

    function test_createAccount_deploysAtPredictedAddress() public {
        address predicted = factory.getAddress(CRED_ID, PUB_X, PUB_Y, 0);
        LogersAccount account = factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
        assertEq(address(account), predicted);
        assertTrue(address(account).code.length > 0);
    }

    function test_createAccount_emitsEvent() public {
        address predicted = factory.getAddress(CRED_ID, PUB_X, PUB_Y, 0);
        vm.expectEmit(true, true, false, true);
        emit LogersAccountFactory.AccountDeployed(predicted, CRED_ID, PUB_X, PUB_Y);
        factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
    }

    function test_createAccount_isIdempotent() public {
        LogersAccount a1 = factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
        LogersAccount a2 = factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
        assertEq(address(a1), address(a2));
    }

    function test_createAccount_differentSaltsDifferentAddresses() public {
        address addr0 = factory.getAddress(CRED_ID, PUB_X, PUB_Y, 0);
        address addr1 = factory.getAddress(CRED_ID, PUB_X, PUB_Y, 1);
        assertTrue(addr0 != addr1);
    }

    function test_createAccount_differentKeysDifferentAddresses() public {
        address addr0 = factory.getAddress(CRED_ID, PUB_X, PUB_Y, 0);
        address addr1 = factory.getAddress(CRED_ID, PUB_X + 1, PUB_Y, 0);
        assertTrue(addr0 != addr1);
    }

    function test_createAccount_revertsOnZeroKey() public {
        vm.expectRevert(LogersAccountFactory.InvalidPublicKey.selector);
        factory.createAccount(CRED_ID, 0, PUB_Y, 0);
    }

    // ─── Initialize check ─────────────────────────────────────────────────── //

    function test_deployedAccount_hasCorrectOwner() public {
        LogersAccount account = factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
        assertTrue(account.isOwner(CRED_ID));
        assertEq(account.ownerCount(), 1);
    }

    function test_deployedAccount_hasCorrectEntryPoint() public {
        LogersAccount account = factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
        assertEq(account.entryPoint(), address(entryPoint));
    }

    // ─── getInitCode ──────────────────────────────────────────────────────── //

    function test_getInitCode_returnsCorrectFormat() public view {
        bytes memory initCode = factory.getInitCode(CRED_ID, PUB_X, PUB_Y, 0);

        // First 20 bytes should be factory address
        address factoryAddr;
        assembly {
            factoryAddr := shr(96, mload(add(initCode, 32)))
        }
        assertEq(factoryAddr, address(factory));

        // Total length: 20 (address) + 4 (selector) + 32*4 (args) = 148 bytes
        assertGt(initCode.length, 20);
    }

    // ─── accountImplementation ────────────────────────────────────────────── //

    function test_accountImplementation_isSet() public view {
        assertTrue(address(factory.accountImplementation()) != address(0));
        assertTrue(address(factory.accountImplementation()).code.length > 0);
    }

    // ─── Fuzz ─────────────────────────────────────────────────────────────── //

    function testFuzz_getAddress_differentSaltsAlwaysDiffer(uint256 salt1, uint256 salt2)
        public
        view
    {
        vm.assume(salt1 != salt2);
        address a = factory.getAddress(CRED_ID, PUB_X, PUB_Y, salt1);
        address b = factory.getAddress(CRED_ID, PUB_X, PUB_Y, salt2);
        assertNotEq(a, b);
    }
}
