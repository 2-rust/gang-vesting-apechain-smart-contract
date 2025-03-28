// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/Gang.sol";

contract GangTest is Test {
    Gang public gangToken;
    address public owner;
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    // Define custom errors for testing
    error InsufficientAllowance();
    error InsufficientBalance();

    function setUp() public {
        owner = address(this);
        gangToken = new Gang();
    }

    // Test basic token metadata
    function testTokenMetadata() public view {
        assertEq(gangToken.name(), "Gutter Token");
        assertEq(gangToken.symbol(), "GANG");
        assertEq(gangToken.decimals(), 18);
    }

    // Test initial supply and minting
    function testInitialMint() public view {
        assertEq(gangToken.totalSupply(), MAX_SUPPLY);
        assertEq(gangToken.balanceOf(owner), MAX_SUPPLY);
    }

    // Test transfer functionality
    function testTransfer() public {
        uint256 amount = 1000 * 10 ** 18;

        bool success = gangToken.transfer(user1, amount);
        assertTrue(success);
        assertEq(gangToken.balanceOf(owner), MAX_SUPPLY - amount);
        assertEq(gangToken.balanceOf(user1), amount);
    }

    // Test transfer with insufficient balance
    function testRevertWhenTransferInsufficientBalance() public {
        uint256 amount = 1000 * 10 ** 18;

        // Transfer all tokens to user1 first
        gangToken.transfer(user1, MAX_SUPPLY);

        // Expect revert with custom error when transferring from owner with 0 balance
        vm.prank(owner);
        vm.expectRevert(InsufficientBalance.selector);
        gangToken.transfer(user2, amount);
    }

    // Test approve and transferFrom
    function testApproveAndTransferFrom() public {
        uint256 amount = 1000 * 10 ** 18;

        // Approve user1 to spend tokens
        bool approveSuccess = gangToken.approve(user1, amount);
        assertTrue(approveSuccess);
        assertEq(gangToken.allowance(owner, user1), amount);

        // Transfer from owner to user2 using user1
        vm.prank(user1);
        bool transferSuccess = gangToken.transferFrom(owner, user2, amount);
        assertTrue(transferSuccess);

        assertEq(gangToken.balanceOf(owner), MAX_SUPPLY - amount);
        assertEq(gangToken.balanceOf(user2), amount);
        assertEq(gangToken.allowance(owner, user1), 0);
    }

    // Test transferFrom with insufficient allowance
    function testRevertWhenTransferFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;

        // Approve less than the transfer amount
        gangToken.approve(user1, amount - 1);

        // Expect revert with custom error when transferring more than allowed
        vm.prank(user1);
        vm.expectRevert(InsufficientAllowance.selector);
        gangToken.transferFrom(owner, user2, amount);
    }

    // Fuzz test for transfer
    function testFuzzTransfer(uint256 amount) public {
        vm.assume(amount <= MAX_SUPPLY);

        bool success = gangToken.transfer(user1, amount);
        assertTrue(success);

        assertEq(gangToken.balanceOf(owner), MAX_SUPPLY - amount);
        assertEq(gangToken.balanceOf(user1), amount);
    }
}
