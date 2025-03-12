// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./MultiRootVestingTestBase.sol";

contract MultiRootVestingCoverageTest is MultiRootVestingTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testCalculateVestingBeforeStart() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp + 10 days); // Start in the future
        uint32 end = uint32(block.timestamp + 365 days);

        // Generate a new leaf and proof for these specific parameters
        bytes32[] memory customLeaves = new bytes32[](2);
        customLeaves[0] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));
        // Add a second leaf to avoid Merkle tree issues
        customLeaves[1] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(2), user2, uint256(200e18), start, end));

        // Update the Merkle root for the Cat collection
        bytes32 newRoot = merkle.getRoot(customLeaves);
        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        // warp back to before the start and try to get vesting info
        vm.warp(start - 1);

        (, uint256 vestable) =
            vestContract.getVesting(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Should be zero as vesting hasn't started
        assertEq(vestable, 0);
    }

    function testCalculateVestingBeforeOneDay() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        // Use existing proof for this test as the parameters match
        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Make initial claim
        vm.warp(start + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Try to check vesting just a little bit later (less than 1 day)
        vm.warp(block.timestamp + 12 hours);

        (, uint256 vestable) =
            vestContract.getVesting(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Should be zero as it's less than 1 day since last claim
        assertEq(vestable, 0);
    }

    function testCalculateVestingAfterExpiryWindow() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 30 days);

        // Generate a new leaf and proof for these specific parameters
        bytes32[] memory customLeaves = new bytes32[](2);
        customLeaves[0] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));
        // Add a second leaf to avoid Merkle tree issues
        customLeaves[1] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(2), user2, uint256(200e18), start, end));

        // Update the Merkle root for the Cat collection
        bytes32 newRoot = merkle.getRoot(customLeaves);
        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        bytes32[] memory proof = merkle.getProof(customLeaves, 0);

        // Make an initial claim
        vm.warp(start + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Now warp to after expiry window (end + 69 days)
        vm.warp(end + 70 days);

        (, uint256 vestable) =
            vestContract.getVesting(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Should be zero as it's after expiry window
        assertEq(vestable, 0);
    }

    function testClaimEcosystemFundsBeforeExpiry() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 30 days);

        // Generate a new leaf and proof for these specific parameters
        bytes32[] memory customLeaves = new bytes32[](2);
        customLeaves[0] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));
        // Add a second leaf to avoid Merkle tree issues
        customLeaves[1] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(2), user2, uint256(200e18), start, end));

        // Update the Merkle root for the Cat collection
        bytes32 newRoot = merkle.getRoot(customLeaves);
        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        bytes32[] memory proof = merkle.getProof(customLeaves, 0);

        // Set ecosystem address
        vm.prank(owner);
        vestContract.setEcosystemAddress(owner);

        // Make partial claim
        vm.warp(start + 10 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Try to claim ecosystem funds before expiry window
        vm.warp(end + 30 days); // Only 30 days after end, not 69+

        bytes32 leaf =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("EcosystemClaimTooEarly()"));
        vestContract.claimEcosystemFunds(leaf);
    }

    function testClaimEcosystemFundsWithZeroUnclaimed() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 30 days);

        // Generate a new leaf and proof for these specific parameters
        bytes32[] memory customLeaves = new bytes32[](2);
        customLeaves[0] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));
        // Add a second leaf to avoid Merkle tree issues
        customLeaves[1] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(2), user2, uint256(200e18), start, end));

        // Update the Merkle root for the Cat collection
        bytes32 newRoot = merkle.getRoot(customLeaves);
        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        bytes32[] memory proof = merkle.getProof(customLeaves, 0);

        // Set ecosystem address
        vm.prank(owner);
        vestContract.setEcosystemAddress(owner);

        // Move to after vesting end to claim full amount
        vm.warp(end + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Move to after expiry
        vm.warp(end + 70 days);

        // Try to claim ecosystem funds when nothing is left
        bytes32 leaf =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));

        uint256 initialBalance = token.balanceOf(owner);

        vm.prank(owner);
        vestContract.claimEcosystemFunds(leaf);

        // Balance should remain unchanged
        assertEq(token.balanceOf(owner), initialBalance);
    }

    function testTimestampEdgeCases() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 invalidEnd = uint32(block.timestamp - 1); // End before start

        // Generate a new leaf and proof for these specific parameters
        bytes32[] memory customLeaves = new bytes32[](2);
        customLeaves[0] =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, invalidEnd));
        // Add a second leaf to avoid Merkle tree issues
        customLeaves[1] = keccak256(
            abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(2), user2, uint256(200e18), start, invalidEnd)
        );

        // Update the Merkle root for the Cat collection
        bytes32 newRoot = merkle.getRoot(customLeaves);
        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        bytes32[] memory proof = merkle.getProof(customLeaves, 0);

        // Move to vesting period
        vm.warp(start + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, invalidEnd);

        // Vesting should still work even with invalid timestamps
        assertGt(token.balanceOf(user1), 0);
    }

    function testInvalidCollectionInGetVesting() public {
        // Create calldata for getVesting() with an invalid collection (value 18)
        bytes memory callData = abi.encodeWithSignature(
            "getVesting(uint8,uint256,address,uint256,uint32,uint32)",
            18, // Invalid collection value
            uint256(1),
            user1,
            100e18,
            uint32(block.timestamp),
            uint32(block.timestamp + 365 days)
        );

        // This should revert with InvalidCollection error
        vm.expectRevert(abi.encodeWithSignature("InvalidCollection()"));
        (bool success,) = address(vestContract).call(callData);
        require(!success, "Call should have failed");
    }

    function testInvalidCollectionInClaim() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Create calldata for claim() with an invalid collection (value 18)
        bytes memory callData = abi.encodeWithSignature(
            "claim(bytes32[],uint8,uint256,address,uint256,uint32,uint32)",
            proof,
            18, // Invalid collection value
            uint256(1),
            user1,
            amount,
            start,
            end
        );

        // This should revert with InvalidCollection error
        vm.expectRevert(abi.encodeWithSignature("InvalidCollection()"));
        (bool success,) = address(vestContract).call(callData);
        require(!success, "Call should have failed");
    }

    function testVestingAccruedWithLongPeriod() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to 10% of vesting period
        vm.warp(start + 36 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        uint256 initialBalance = token.balanceOf(user1);

        // Move to 90% of vesting period
        vm.warp(start + 328 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Should have claimed approximately 80% more tokens
        uint256 newTokens = token.balanceOf(user1) - initialBalance;
        assertApproxEqRel(newTokens, amount * 80 / 100, 0.01e18); // 1% tolerance
    }

    function testClaimWithDifferentRecipient() public {
        uint256 amount = 200e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        // Use the leaf for user2's vesting
        bytes32[] memory proof = merkle.getProof(catLeaves, 1);

        // Move to after vesting start
        vm.warp(start + 1 days);

        // Have user1 try to claim user2's vesting
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidMerkleProof()"));
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(2), user1, amount, start, end);

        // Now have user2 claim correctly
        vm.prank(user2);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(2), user2, amount, start, end);

        // User2 should have received tokens
        assertGt(token.balanceOf(user2), 0);
    }
}
