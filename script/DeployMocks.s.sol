// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol"; // Adjust path based on your project structure
import "../test/mocks/MockERC721.sol"; // Adjust path based on your project structure

contract DeployMocks is Script {
    function run() external {
        string memory rpc = "https://curtis.rpc.caldera.xyz/http";
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);

        // Deploy MockERC20
        string memory erc20Name = "Mock Token";
        string memory erc20Symbol = "MTK";
        uint8 erc20Decimals = 18;

        MockERC20 mockERC20 = new MockERC20(erc20Name, erc20Symbol, erc20Decimals);
        console.log("MockERC20 deployed at:", address(mockERC20));

        // Mint some tokens to the deployer
        mockERC20.mint(msg.sender, 1000000 * 10 ** 18); // 1M tokens
        console.log("Minted 1M tokens to:", msg.sender);

        // Deploy MockERC721
        string memory erc721Name = "Mock NFT";
        string memory erc721Symbol = "MNFT";

        MockERC721 mockERC721 = new MockERC721(erc721Name, erc721Symbol);
        console.log("MockERC721 deployed at:", address(mockERC721));

        // Mint an NFT to the deployer
        uint256 tokenId = mockERC721.mint(msg.sender);
        console.log("Minted NFT with tokenId:", tokenId, "to:", msg.sender);

        vm.stopBroadcast();
    }
}
