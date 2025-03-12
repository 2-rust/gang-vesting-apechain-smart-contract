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

    // NFT collections (mainnet)
    MockERC721 catNFT;
    MockERC721 ratNFT;
    MockERC721 dogNFT;
    MockERC721 pigeonNFT;
    MockERC721 baycNFT;
    MockERC721 maycNFT;
    MockERC721 n1forceNFT;
    MockERC721 kanpaiPandasNFT;
    MockERC721 quirkiesNFT;

    // APECHAIN NFT Collections
    MockERC721 geezOnApeNFT;

    Merkle merkle;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address user3 = address(0x4);
    address user4 = address(0x5);

    bytes32[] public catLeaves;
    bytes32[] public teamLeaves;
    bytes32[] public seedLeaves;
    bytes32[] public strategicLeaves;
    bytes32[] public communityPresaleLeaves;
    bytes32[] public ecosystemLeaves;
    bytes32[] public apechainLeaves;
    bytes32[] public liquidityLeaves;
    bytes32[] public roots;
    MultiRootVesting.Collection[] public collections;
    address[] public nftAddresses;

    function setUp() public virtual {
        vm.startPrank(owner);

        // Deploy mock tokens
        token = new MockERC20("Test Token", "TEST", 18);

        // Deploy mock NFTs for all collections
        catNFT = new MockERC721("Cat NFT", "CAT");
        ratNFT = new MockERC721("Rat NFT", "RAT");
        dogNFT = new MockERC721("Dog NFT", "DOG");
        pigeonNFT = new MockERC721("Pigeon NFT", "PGN");
        baycNFT = new MockERC721("BAYC", "BAYC");
        maycNFT = new MockERC721("MAYC", "MAYC");
        n1forceNFT = new MockERC721("n1force", "N1F");
        kanpaiPandasNFT = new MockERC721("Kanpai Pandas", "KNPP");
        quirkiesNFT = new MockERC721("Quirkies", "QRKS");
        geezOnApeNFT = new MockERC721("Geez On Ape", "GOA");

        merkle = new Merkle();
        setupTestData();

        // Set up NFT addresses array for all 10 NFT collections
        nftAddresses = [
            address(catNFT),
            address(ratNFT),
            address(dogNFT),
            address(pigeonNFT),
            address(baycNFT),
            address(maycNFT),
            address(n1forceNFT),
            address(kanpaiPandasNFT),
            address(quirkiesNFT),
            address(geezOnApeNFT)
        ];

        vestContract = new MultiRootVesting(collections, roots, nftAddresses, address(token));

        // Mint tokens to owner for vesting
        token.mint(owner, 1000000e18);
        token.approve(address(vestContract), type(uint256).max);
        token.transfer(address(vestContract), 1400e18);

        // Mint NFTs to users
        catNFT.mint(user1);
        catNFT.mint(user2);
        baycNFT.mint(user3);
        geezOnApeNFT.mint(user4);

        vm.stopPrank();
    }

    function setupTestData() internal {
        // Setup collections array with all 18 collections
        collections = new MultiRootVesting.Collection[](18);
        collections[0] = MultiRootVesting.Collection.Cat;
        collections[1] = MultiRootVesting.Collection.Rat;
        collections[2] = MultiRootVesting.Collection.Dog;
        collections[3] = MultiRootVesting.Collection.Pigeon;
        collections[4] = MultiRootVesting.Collection.BAYC;
        collections[5] = MultiRootVesting.Collection.MAYC;
        collections[6] = MultiRootVesting.Collection.n1force;
        collections[7] = MultiRootVesting.Collection.kanpaiPandas;
        collections[8] = MultiRootVesting.Collection.quirkies;
        collections[9] = MultiRootVesting.Collection.geezOnApe;
        collections[10] = MultiRootVesting.Collection.Crab;
        collections[11] = MultiRootVesting.Collection.Team;
        collections[12] = MultiRootVesting.Collection.SeedRound;
        collections[13] = MultiRootVesting.Collection.StrategicRound;
        collections[14] = MultiRootVesting.Collection.CommunityPresale;
        collections[15] = MultiRootVesting.Collection.Ecosystem;
        collections[16] = MultiRootVesting.Collection.Apechain;
        collections[17] = MultiRootVesting.Collection.Liquidity;

        // Create test data for Cat collection
        catLeaves = new bytes32[](2);
        catLeaves[0] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Cat,
                uint256(1),
                user1,
                uint256(100e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 365 days)
            )
        );
        catLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Cat,
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
                MultiRootVesting.Collection.Team,
                uint256(1),
                user3,
                uint256(300e18),
                uint32(block.timestamp + 30 days),
                uint32(block.timestamp + 395 days)
            )
        );
        teamLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Team,
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
                MultiRootVesting.Collection.SeedRound,
                uint256(1),
                user1,
                uint256(400e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 180 days)
            )
        );
        seedLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.SeedRound,
                uint256(2),
                user2,
                uint256(200e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 180 days)
            )
        );

        // Create test data for StrategicRound collection
        strategicLeaves = new bytes32[](2);
        strategicLeaves[0] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.StrategicRound,
                uint256(1),
                user3,
                uint256(250e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 365 days)
            )
        );
        strategicLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.StrategicRound,
                uint256(2),
                user4,
                uint256(175e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 365 days)
            )
        );

        // Create test data for CommunityPresale collection
        communityPresaleLeaves = new bytes32[](2);
        communityPresaleLeaves[0] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.CommunityPresale,
                uint256(1),
                user1,
                uint256(50e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 90 days)
            )
        );
        communityPresaleLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.CommunityPresale,
                uint256(2),
                user2,
                uint256(75e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 90 days)
            )
        );

        // Create test data for Ecosystem collection
        ecosystemLeaves = new bytes32[](2);
        ecosystemLeaves[0] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Ecosystem,
                uint256(1),
                user3,
                uint256(500e18),
                uint32(block.timestamp + 60 days),
                uint32(block.timestamp + 425 days)
            )
        );
        ecosystemLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Ecosystem,
                uint256(2),
                user4,
                uint256(350e18),
                uint32(block.timestamp + 60 days),
                uint32(block.timestamp + 425 days)
            )
        );

        // Create test data for Apechain collection
        apechainLeaves = new bytes32[](2);
        apechainLeaves[0] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Apechain,
                uint256(1),
                user1,
                uint256(125e18),
                uint32(block.timestamp + 90 days),
                uint32(block.timestamp + 455 days)
            )
        );
        apechainLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Apechain,
                uint256(2),
                user2,
                uint256(225e18),
                uint32(block.timestamp + 90 days),
                uint32(block.timestamp + 455 days)
            )
        );

        // Create test data for Liquidity collection
        liquidityLeaves = new bytes32[](2);
        liquidityLeaves[0] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Liquidity,
                uint256(1),
                user3,
                uint256(600e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 730 days)
            )
        );
        liquidityLeaves[1] = keccak256(
            abi.encodePacked(
                MultiRootVesting.Collection.Liquidity,
                uint256(2),
                user4,
                uint256(450e18),
                uint32(block.timestamp),
                uint32(block.timestamp + 730 days)
            )
        );

        // Generate roots for all 18 collections
        roots = new bytes32[](18);
        roots[0] = merkle.getRoot(catLeaves); // Cat
        roots[1] = keccak256(abi.encodePacked("dummy root for Rat")); // Rat
        roots[2] = keccak256(abi.encodePacked("dummy root for Dog")); // Dog
        roots[3] = keccak256(abi.encodePacked("dummy root for Pigeon")); // Pigeon
        roots[4] = keccak256(abi.encodePacked("dummy root for BAYC")); // BAYC
        roots[5] = keccak256(abi.encodePacked("dummy root for MAYC")); // MAYC
        roots[6] = keccak256(abi.encodePacked("dummy root for n1force")); // n1force
        roots[7] = keccak256(abi.encodePacked("dummy root for kanpaiPandas")); // kanpaiPandas
        roots[8] = keccak256(abi.encodePacked("dummy root for quirkies")); // quirkies
        roots[9] = keccak256(abi.encodePacked("dummy root for geezOnApe")); // geezOnApe
        roots[10] = keccak256(abi.encodePacked("dummy root for Crab")); // Crab
        roots[11] = merkle.getRoot(teamLeaves); // Team
        roots[12] = merkle.getRoot(seedLeaves); // SeedRound
        roots[13] = merkle.getRoot(strategicLeaves); // StrategicRound
        roots[14] = merkle.getRoot(communityPresaleLeaves); // CommunityPresale
        roots[15] = merkle.getRoot(ecosystemLeaves); // Ecosystem
        roots[16] = merkle.getRoot(apechainLeaves); // Apechain
        roots[17] = merkle.getRoot(liquidityLeaves); // Liquidity
    }
}
