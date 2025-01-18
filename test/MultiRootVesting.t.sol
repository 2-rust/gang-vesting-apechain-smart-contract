// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/MultiRootVesting.sol";
import "@solady/src/tokens/ERC20.sol";
import "./mocks/MockERC20.sol";
import "@murky/Merkle.sol";

contract MultiRootVestingTest is Test {
    MultiRootVesting vest;
    MockERC20 token;
    Merkle merkle;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address user3 = address(0x4);
    address user4 = address(0x5);

    // Test data
    bytes32[] public catLeaves;
    bytes32[] public teamLeaves;
    bytes32[] public seedLeaves;
    bytes32[] public roots;
    MultiRootVesting.Collection[] public collections;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock token
        token = new MockERC20("Test Token", "TEST", 18);

        // Initialize Murky
        merkle = new Merkle();

        // Setup test data for each collection
        setupTestData();

        // Deploy vesting contract
        vest = new MultiRootVesting(collections, roots, address(token));

        // Mint tokens to owner for vesting
        token.mint(owner, 1000000e18);
        token.approve(address(vest), type(uint256).max);
        // Transfer some tokens to vesting contract
        token.transfer(address(vest), 1400e18);

        vm.stopPrank();
    }

    function setupTestData() internal {
        // Setup collections array
        collections =
            [MultiRootVesting.Collection.Cat, MultiRootVesting.Collection.Team, MultiRootVesting.Collection.SeedRound];

        // Create test data for Cat collection
        catLeaves = new bytes32[](2);
        catLeaves[0] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.Cat),
                address(token),
                user1,
                uint256(100e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 365 days)
            )
        );
        catLeaves[1] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.Cat),
                address(token),
                user2,
                uint256(200e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 365 days)
            )
        );

        // Create test data for Team collection
        teamLeaves = new bytes32[](2);
        teamLeaves[0] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.Team),
                address(token),
                user3,
                uint256(300e18),
                uint32(block.timestamp + 30 days),
                uint32(block.timestamp + 395 days)
            )
        );
        teamLeaves[1] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.Team),
                address(token),
                user4,
                uint256(150e18),
                uint32(block.timestamp + 30 days),
                uint32(block.timestamp + 395 days)
            )
        );

        // Create test data for SeedRound collection
        seedLeaves = new bytes32[](2);
        seedLeaves[0] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.SeedRound),
                address(token),
                user1,
                uint256(400e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 180 days)
            )
        );
        seedLeaves[1] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.SeedRound),
                address(token),
                user2,
                uint256(200e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 180 days)
            )
        );

        // Generate roots for each collection
        roots = new bytes32[](3);
        roots[0] = merkle.getRoot(catLeaves);
        roots[1] = merkle.getRoot(teamLeaves);
        roots[2] = merkle.getRoot(seedLeaves);
    }

    function testInitialSetup() public view {
        for (uint256 i = 0; i < collections.length; i++) {
            (bytes32 root, bool locked) = vest.getCollectionRoot(collections[i]);
            assert(root == roots[i]);
            assert(!locked);
        }
    }

    function testLockRoot() public {
        vm.prank(owner);
        vest.lockRoot(MultiRootVesting.Collection.Cat);

        (, bool locked) = vest.getCollectionRoot(MultiRootVesting.Collection.Cat);
        assertTrue(locked);
    }

    function testCannotUpdateLockedRoot() public {
        vm.startPrank(owner);
        vest.lockRoot(MultiRootVesting.Collection.Cat);

        vm.expectRevert(abi.encodeWithSignature("RootLocked()"));
        vest.updateMerkleRoot(MultiRootVesting.Collection.Cat, bytes32(0));

        vm.stopPrank();
    }

    function testUpdateRoot() public {
        bytes32 newRoot = bytes32(uint256(1));

        vm.prank(owner);
        vest.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        (bytes32 root,) = vest.getCollectionRoot(MultiRootVesting.Collection.Cat);
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
        vest.claim(proof, MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        MultiRootVesting.Vesting memory vesting =
            vest.getVesting(MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        assertEq(vesting.amount, amount);
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
        vest.claim(proof, MultiRootVesting.Collection.Team, address(token), user3, amount, start, end);

        MultiRootVesting.Vesting memory vesting =
            vest.getVesting(MultiRootVesting.Collection.Team, address(token), user3, amount, start, end);

        assertEq(vesting.amount, amount);
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

        vest.claim(proof, MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        vest.claim(proof, MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        vm.stopPrank();
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
        vest.claim(proof, MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        // Move forward 182.5 days (50% of vesting period)
        vm.warp(block.timestamp + 182.5 days);

        uint256 vestedAmount =
            vest.vestedAmount(MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        // Should be roughly 50% of total amount
        assertApproxEqRel(vestedAmount, amount / 2, 0.01e18); // 1% tolerance
    }

    function testClaimAfterEnd() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        bytes32[] memory proof = merkle.getProof(catLeaves, 0);

        // Move to after vesting end
        vm.warp(end + 1 days);

        vm.prank(user1);
        vest.claim(proof, MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);

        // Should have received full amount
        assertEq(token.balanceOf(user1), amount);
    }

    function testInvalidProof() public {
        uint256 amount = 100e18;
        uint32 start = uint32(block.timestamp);
        uint32 end = uint32(block.timestamp + 365 days);

        // Use wrong proof (from index 1 instead of 0)
        bytes32[] memory proof = merkle.getProof(catLeaves, 1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidMerkleProof()"));
        vest.claim(proof, MultiRootVesting.Collection.Cat, address(token), user1, amount, start, end);
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
        (bool success,) = address(vest).call(callData);
        require(!success, "Invalid Collection");
    }
}
