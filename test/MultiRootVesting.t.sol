// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "@murky/Merkle.sol";
import "@solady/src/tokens/ERC20.sol";

import "../src/MultiRootVesting.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC721.sol";

contract MultiRootVestingTest is Test {
    MultiRootVesting vestContract;
    MockERC20 token;
    MockERC721 catNFT;
    MockERC721 ratNFT;
    MockERC721 dogNFT;
    MockERC721 pigeonNFT;
    MockERC721 crabNFT;
    Merkle merkle;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address user3 = address(0x4);
    address user4 = address(0x5);

    bytes32[] public catLeaves;
    bytes32[] public teamLeaves;
    bytes32[] public seedLeaves;
    bytes32[] public roots;
    MultiRootVesting.Collection[] public collections;
    address[] public nftAddresses;

    function setUp() public virtual {
        vm.startPrank(owner);

        // Deploy mock tokens
        token = new MockERC20("Test Token", "TEST", 18);
        catNFT = new MockERC721("Cat NFT", "CAT");
        ratNFT = new MockERC721("Rat NFT", "RAT");
        dogNFT = new MockERC721("Dog NFT", "DOG");
        pigeonNFT = new MockERC721("Pigeon NFT", "PGN");
        crabNFT = new MockERC721("Crab NFT", "CRB");

        merkle = new Merkle();
        setupTestData();

        // Set up NFT addresses array
        nftAddresses = [address(catNFT), address(ratNFT), address(dogNFT), address(pigeonNFT), address(crabNFT)];

        vestContract = new MultiRootVesting(collections, roots, nftAddresses, address(token));

        // Mint tokens to owner for vesting
        token.mint(owner, 1000000e18);
        token.approve(address(vestContract), type(uint256).max);
        token.transfer(address(vestContract), 1400e18);

        // Mint NFTs to users
        catNFT.mint(user1);
        catNFT.mint(user2);

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
                uint256(1),
                user1,
                uint256(100e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 365 days)
            )
        );
        catLeaves[1] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.Cat),
                uint256(2),
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
                uint256(1),
                user3,
                uint256(300e18),
                uint32(block.timestamp + 30 days),
                uint32(block.timestamp + 395 days)
            )
        );
        teamLeaves[1] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.Team),
                uint256(2),
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
                uint256(1),
                user1,
                uint256(400e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 180 days)
            )
        );
        seedLeaves[1] = keccak256(
            abi.encodePacked(
                uint8(MultiRootVesting.Collection.SeedRound),
                uint256(2),
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
            (bytes32 root, bool locked) = vestContract.collectionRoots(collections[i]);
            assert(root == roots[i]);
            assert(!locked);
        }
    }

    function testLockRoot() public {
        vm.prank(owner);
        vestContract.lockRoot(MultiRootVesting.Collection.Cat);

        (, bool locked) = vestContract.collectionRoots(MultiRootVesting.Collection.Cat);
        assertTrue(locked);
    }

    function testCannotUpdateLockedRoot() public {
        vm.startPrank(owner);
        vestContract.lockRoot(MultiRootVesting.Collection.Cat);

        vm.expectRevert(abi.encodeWithSignature("RootLocked()"));
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, bytes32(0));

        vm.stopPrank();
    }

    function testUpdateRoot() public {
        bytes32 newRoot = bytes32(uint256(1));

        vm.prank(owner);
        vestContract.updateMerkleRoot(MultiRootVesting.Collection.Cat, newRoot);

        (bytes32 root,) = vestContract.collectionRoots(MultiRootVesting.Collection.Cat);
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
