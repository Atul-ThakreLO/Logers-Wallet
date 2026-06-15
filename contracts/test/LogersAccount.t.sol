// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {TestHelper} from "./helpers/TestHelper.sol";
import {LogersAccount} from "../src/LogersAccount.sol";
import {LogersAccountFactory} from "../src/LogersAccountFactory.sol";
import {ILogersAccount} from "../src/interfaces/ILogersAccount.sol";
import {WebAuthnLib} from "../src/libraries/WebAuthnLib.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract LogersAccountTest is TestHelper {
    LogersAccount internal account;

    function setUp() public override {
        super.setUp();
        // Etch always-true precompile so WebAuthn P256 verification passes in tests
        _deployAlwaysTruePrecompile();
        account = _deployAliceAccount();
    }

    // ─── Initialize ───────────────────────────────────────────────────────── //

    function test_initialize_setsFirstOwner() public view {
        assertTrue(account.isOwner(CRED_ID));
        assertEq(account.ownerCount(), 1);
    }

    function test_initialize_setsEntryPoint() public view {
        assertEq(account.entryPoint(), address(entryPoint));
    }

    function test_initialize_revertsZeroEntryPoint() public {
        // Our guard: passing zero address for entryPoint reverts with ZeroAddress
        vm.expectRevert(LogersAccountFactory.ZeroAddress.selector);
        new LogersAccountFactory(IEntryPoint(address(0)), address(this));
    }

    // ─── execute ──────────────────────────────────────────────────────────── //

    function test_execute_succeeds_fromEntryPoint() public {
        address target = makeAddr("target");
        vm.deal(address(account), 1 ether);

        vm.prank(address(entryPoint));
        vm.expectEmit(true, false, false, true);
        emit ILogersAccount.ExecutedTransaction(target, 0.1 ether, bytes(""));
        account.execute(target, 0.1 ether, bytes(""));

        assertEq(target.balance, 0.1 ether);
    }

    function test_execute_succeeds_fromSelf() public {
        address target = makeAddr("selfTarget");
        vm.deal(address(account), 1 ether);

        vm.prank(address(account));
        account.execute(target, 0, bytes(""));
    }

    function test_execute_reverts_fromNonEntryPoint() public {
        vm.prank(alice);
        vm.expectRevert(LogersAccount.OnlyEntryPointOrSelf.selector);
        account.execute(bob, 0, bytes(""));
    }

    function test_execute_reverts_onFailedCall() public {
        // Calling a contract that reverts
        address badTarget = makeAddr("badTarget");
        vm.etch(badTarget, hex"fd"); // REVERT opcode
        vm.deal(address(account), 0);

        vm.prank(address(entryPoint));
        vm.expectRevert(
            abi.encodeWithSelector(LogersAccount.ExecutionFailed.selector, badTarget, bytes(""))
        );
        account.execute(badTarget, 0, bytes(""));
    }

    function test_execute_reverts_onZeroTarget() public {
        vm.prank(address(entryPoint));
        vm.expectRevert(LogersAccount.ZeroAddress.selector);
        account.execute(address(0), 0, bytes(""));
    }

    // ─── executeBatch ─────────────────────────────────────────────────────── //

    function test_executeBatch_succeeds() public {
        address t1 = makeAddr("t1");
        address t2 = makeAddr("t2");
        vm.deal(address(account), 2 ether);

        ILogersAccount.Call[] memory calls = new ILogersAccount.Call[](2);
        calls[0] = ILogersAccount.Call({target: t1, value: 0.5 ether, data: bytes("")});
        calls[1] = ILogersAccount.Call({target: t2, value: 0.3 ether, data: bytes("")});

        vm.prank(address(entryPoint));
        vm.expectEmit(false, false, false, true);
        emit ILogersAccount.ExecutedBatch(2);
        account.executeBatch(calls);

        assertEq(t1.balance, 0.5 ether);
        assertEq(t2.balance, 0.3 ether);
    }

    // ─── addOwner / removeOwner ───────────────────────────────────────────── //

    function test_addOwner_addsCorrectly() public {
        bytes32 newCred = keccak256("new-cred");
        uint256 newX = PUB_X + 1;
        uint256 newY = PUB_Y + 1;

        vm.prank(address(entryPoint));
        vm.expectEmit(true, false, false, true);
        emit ILogersAccount.OwnerAdded(newCred, newX, newY);
        account.addOwner(newCred, newX, newY);

        assertTrue(account.isOwner(newCred));
        assertEq(account.ownerCount(), 2);
    }

    function test_addOwner_revertsOnDuplicate() public {
        vm.prank(address(entryPoint));
        vm.expectRevert(abi.encodeWithSelector(LogersAccount.OwnerAlreadyExists.selector, CRED_ID));
        account.addOwner(CRED_ID, PUB_X, PUB_Y);
    }

    function test_addOwner_revertsInvalidKey() public {
        vm.prank(address(entryPoint));
        vm.expectRevert(LogersAccount.InvalidPublicKey.selector);
        account.addOwner(keccak256("x"), 0, PUB_Y);
    }

    function test_removeOwner_removesCorrectly() public {
        bytes32 cred2 = keccak256("cred2");
        vm.prank(address(entryPoint));
        account.addOwner(cred2, PUB_X + 1, PUB_Y + 1);

        vm.prank(address(entryPoint));
        vm.expectEmit(true, false, false, false);
        emit ILogersAccount.OwnerRemoved(cred2);
        account.removeOwner(cred2);

        assertFalse(account.isOwner(cred2));
        assertEq(account.ownerCount(), 1);
    }

    function test_removeOwner_revertsOnLastOwner() public {
        vm.prank(address(entryPoint));
        vm.expectRevert(LogersAccount.MustHaveAtLeastOneOwner.selector);
        account.removeOwner(CRED_ID);
    }

    function test_removeOwner_revertsOwnerNotFound() public {
        vm.prank(address(entryPoint));
        vm.expectRevert(
            abi.encodeWithSelector(LogersAccount.OwnerNotFound.selector, keccak256("nonexistent"))
        );
        account.removeOwner(keccak256("nonexistent"));
    }

    // ─── isValidSignature (ERC-1271) ──────────────────────────────────────── //

    function test_isValidSignature_returnsInvalid_forUnknownCred() public view {
        bytes32 hash = keccak256("test hash");
        WebAuthnLib.WebAuthnAuth memory auth = WebAuthnLib.WebAuthnAuth({
            authenticatorData: abi.encodePacked(keccak256("rp"), bytes1(0x05), bytes4(uint32(1))),
            clientDataJSON: '{"type":"webauthn.get","challenge":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","origin":"http://localhost:3000"}',
            challengeIndex: 23,
            typeIndex: 1,
            r: PUB_X,
            s: PUB_Y
        });
        bytes memory sig = abi.encode(keccak256("unknown-cred"), auth);
        bytes4 result = account.isValidSignature(hash, sig);
        assertEq(result, bytes4(0xffffffff));
    }

    // ─── UUPS upgrade authorization ───────────────────────────────────────── //

    function test_upgradeAuth_revertsFromNonEntryPoint() public {
        address newImpl = address(new LogersAccount());
        vm.prank(alice);
        vm.expectRevert(LogersAccount.OnlyEntryPointOrSelf.selector);
        account.upgradeToAndCall(newImpl, bytes(""));
    }

    function test_upgradeAuth_revertsZeroAddress() public {
        vm.prank(address(entryPoint));
        vm.expectRevert(LogersAccount.ZeroAddress.selector);
        account.upgradeToAndCall(address(0), bytes(""));
    }

    // ─── View helpers ─────────────────────────────────────────────────────── //

    function test_getAllCredentialIds_returnsAll() public {
        bytes32 cred2 = keccak256("cred2");
        vm.prank(address(entryPoint));
        account.addOwner(cred2, PUB_X + 1, PUB_Y + 1);

        bytes32[] memory ids = account.getAllCredentialIds();
        assertEq(ids.length, 2);
        assertEq(ids[0], CRED_ID);
        assertEq(ids[1], cred2);
    }

    function test_getOwner_revertsForInactive() public {
        vm.expectRevert(
            abi.encodeWithSelector(LogersAccount.OwnerNotFound.selector, keccak256("ghost"))
        );
        account.getOwner(keccak256("ghost"));
    }

    // ─── Receive ETH ──────────────────────────────────────────────────────── //

    function test_receive_acceptsETH() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(account).call{value: 0.5 ether}("");
        assertTrue(ok);
        assertEq(address(account).balance, 0.5 ether);
    }
}
