// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol";
import "../test/mocks/MockERC721.sol";
import "../src/MultiRootVesting.sol";

contract DeployAll is Script {
    function run() external {
        string memory rpc = "https://curtis.rpc.caldera.xyz/http";
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Derive and log the address from the private key
        address deployer = vm.addr(privateKey);
        console.log("Deployer address:", deployer);

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);

        // Deploy MockERC20 (to be used as vesting token)
        string memory erc20Name = "Mock Token";
        string memory erc20Symbol = "MTK";
        uint8 erc20Decimals = 18;

        MockERC20 mockERC20 = new MockERC20(erc20Name, erc20Symbol, erc20Decimals);
        console.log("MockERC20 deployed at:", address(mockERC20));

        // Deploy MockERC721 (to simulate an NFT collection)
        string memory erc721Name = "Mock NFT";
        string memory erc721Symbol = "MNFT";

        MockERC721 mockERC721 = new MockERC721(erc721Name, erc721Symbol);
        console.log("MockERC721 deployed at:", address(mockERC721));

        // Mint an NFT to the deployer
        uint256 tokenId = mockERC721.mint(msg.sender);
        console.log("Minted NFT with tokenId:", tokenId, "to:", deployer);

        // Configure MultiRootVesting parameters with all 18 collections
        MultiRootVesting.Collection[] memory collections = new MultiRootVesting.Collection[](18);
        bytes32[] memory roots = new bytes32[](18);
        address[] memory nftAddresses = new address[](10);

        // Initialize all 18 collections
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

        // Set dummy Merkle roots for each collection
        for (uint256 i = 0; i < 18; i++) {
            roots[i] = keccak256(abi.encodePacked("dummy root for collection ", i));
        }

        // Set up NFT addresses for the first 10 collections (Cat to quirkies)
        for (uint256 i = 0; i < 10; i++) {
            nftAddresses[i] = address(mockERC721);
        }

        // Deploy MultiRootVesting with MockERC20 as vesting token
        MultiRootVesting vesting = new MultiRootVesting(collections, roots, nftAddresses, address(mockERC20));
        console.log("MultiRootVesting deployed at:", address(vesting));

        // Mint 1 billion tokens to the vesting contract
        mockERC20.mint(address(vesting), 1_000_000_000 * 10 ** 18); // 1B tokens
        console.log("Minted 1B tokens to vesting contract:", address(vesting));

        vm.stopBroadcast();
    }
}
