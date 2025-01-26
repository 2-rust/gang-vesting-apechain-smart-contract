// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./MultiRootVestingTestBase.sol";

contract MultiRootVestingTest is MultiRootVestingTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testConstructorValidation() public {
        address[] memory invalidNFTs = new address[](4); // Wrong length
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        new MultiRootVesting(collections, roots, invalidNFTs, address(token));

        address[] memory invalidAddresses = new address[](5);
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        new MultiRootVesting(collections, roots, invalidAddresses, address(token));
    }

    function testInitialSetup() public view {
        for (uint256 i = 0; i < collections.length; i++) {
            bytes32 root = vestContract.collectionRoots(collections[i]);
            assert(root == roots[i]);
        }
    }

    function testLockRoots() public {
        vm.prank(owner);
        vestContract.lockRoots();

        assertTrue(vestContract.rootsLocked());
    }

    function testCannotUpdateRootAfterLock() public {
        vm.startPrank(owner);
        vestContract.lockRoots();

        vm.expectRevert(abi.encodeWithSignature("RootLocked()"));
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, bytes32(0));

        vm.stopPrank();
    }

    function testUpdateRoot() public {
        bytes32 newRoot = bytes32(uint256(1));

        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        bytes32 root = vestContract.collectionRoots(MultiRootVesting.Collection.Cat);
        assertEq(root, newRoot);
    }

    function testClaimCat() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting end
        vm.warp(start + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        (MultiRootVesting.Vesting memory vesting,) =
            vestContract.getVesting(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        assertGt(vesting.claimed, 0);
        assertEq(vesting.totalClaim, amount);
        assertEq(vesting.recipient, user1);
        assertEq(uint8(vesting.collection), uint8(MultiRootVesting.Collection.Cat));
    }

    function testClaimTeam() public {
        uint256 amount = 300e18;
        uint32 start = uint32(block.timestamp + 30 days);
        uint32 end = uint32(block.timestamp + 395 days);

        bytes32[] memory proof = merkle.getProof(teamLeaves, 0);

        // Move to after vesting end
        vm.warp(start + 1 days);

        vm.prank(user3);
        vestContract.claim(proof, MultiRootVesting.Collection.Team, uint256(1), user3, amount, start, end);

        (MultiRootVesting.Vesting memory vesting,) =
            vestContract.getVesting(MultiRootVesting.Collection.Team, uint256(1), user3, amount, start, end);

        assertGt(vesting.claimed, 0);
        assertEq(vesting.totalClaim, amount);
        assertEq(vesting.recipient, user3);
        assertEq(uint8(vesting.collection), uint8(MultiRootVesting.Collection.Team));
    }

    function testCannotClaimTwice() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting end
        vm.warp(start + 1 days);

        vm.startPrank(user1);

        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        vm.stopPrank();
    }

    function testCannotClaimWithinOneDayOfPreviousClaim() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting start
        vm.warp(start + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Try to claim again within 1 day
        vm.warp(start + 1.5 days);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);
    }

    function testCanClaimAfterOneDayOfPreviousClaim() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting start
        vm.warp(start + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Move forward more than 1 day
        vm.warp(start + 2 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Verify some tokens were claimed
        (MultiRootVesting.Vesting memory vesting,) =
            vestContract.getVesting(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        assertGt(vesting.claimed, 0);
        assertLt(vesting.claimed, amount);
    }

    function testVestedAmountCalculation() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting end
        vm.warp(start + 1 days);

        // Claim at start
        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Move forward 181.5 days (50% of vesting period after first claim)
        vm.warp(block.timestamp + 181.5 days);

        (, uint256 vestable) =
            vestContract.getVesting(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Should be roughly 50% of total amount
        assertApproxEqRel(vestable, amount / 2, 0.01e18); // 1% tolerance
    }

    function testClaimAfterEnd() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting end
        vm.warp(end + 1 days);

        vm.prank(user1);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);

        // Should have received full amount
        assertEq(token.balanceOf(user1), amount);
    }

    function testCannotClaimAfterExpiration() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Claim initial vesting
        vm.startPrank(user1);
        vm.warp(start + 1 days);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);
        vm.stopPrank();

        // Move past end and 69 days
        vm.warp(end + 70 days);

        // Try to claim again
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);
    }

    function testWithdrawExpiredFunds() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Set ecosystem address
        vm.prank(owner);
        vestContract.setEcosystemAddress(owner);

        // Claim initial vesting
        vm.startPrank(user1);
        vm.warp(start + 1 days);
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);
        vm.stopPrank();

        // Move past end and 69 days
        vm.warp(end + 70 days);

        // Check initial balance
        uint256 initialEcosystemBalance = token.balanceOf(owner);

        // Withdraw expired funds
        vm.prank(owner);
        // Claim expired funds accumulated
        bytes32 leaf =
            keccak256(abi.encodePacked(MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end));
        vestContract.claimEcosystemFunds(leaf);

        // Check balance increased
        uint256 finalEcosystemBalance = token.balanceOf(owner);

        assertGt(finalEcosystemBalance, initialEcosystemBalance);
    }

    function testInvalidProof() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        // Use wrong proof (from index 1 instead of 0)
        bytes32[] memory proof = merkle.getProof(catLeaves, 1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidMerkleProof()"));
        vestContract.claim(proof, MultiRootVesting.Collection.Cat, uint256(1), user1, amount, start, end);
    }

    function testInvalidCollection() public {
        // Create calldata for vestedAmount() with an invalid collection (value 12)
        bytes memory callData = abi.encodeWithSignature(
            "vestedAmount(uint8,address,address,uint256,uint32,uint32)",
            12, // Invalid collection value
            address(token),
            user1,
            100e18,
            uint32(block.timestamp),
            uint32(block.timestamp + 365 days)
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidCollection()"));
        (bool success,) = address(vestContract).call(callData);
        require(!success, "Invalid Collection");
    }
}
