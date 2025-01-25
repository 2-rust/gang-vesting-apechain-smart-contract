// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "@murky/Merkle.sol";
import "@solady/src/tokens/ERC20.sol";

import "../src/MultiRootVesting.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC721.sol";

contract MultiRootVestingTestBase is Test {
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
}
