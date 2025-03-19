// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol";
import "../test/mocks/MockERC721.sol";
import "../src/GangVesting.sol";

contract DeployGangVesting is Script {
    function run() external {
        string memory rpc = "https://curtis.rpc.caldera.xyz/http";
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Derive and log the address from the private key
        address deployer = vm.addr(privateKey);
        console.log("Deployer address:", deployer);

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);

        // Deploy MockERC20 (to be used as vesting token)
        string memory erc20Name = "MOCK Token";
        string memory erc20Symbol = "GT20";
        uint8 erc20Decimals = 18;
        MockERC20 mockERC20 = new MockERC20(erc20Name, erc20Symbol, erc20Decimals);
        console.log("MockERC20 deployed at:", address(mockERC20));

        // Deploy MockERC721 (to simulate the Gang NFT collection)
        string memory erc721Name = "MOCK NFT";
        string memory erc721Symbol = "GNFT";
        MockERC721 mockERC721 = new MockERC721(erc721Name, erc721Symbol);
        console.log("MockERC721 deployed at:", address(mockERC721));

        // Mint an NFT to the deployer
        uint256 tokenId = mockERC721.mint(msg.sender);
        console.log("Minted NFT with tokenId:", tokenId, "to:", deployer);

        // Create sample data for Merkle tree (this would be generated off-chain in production)
        // Here we're just creating a dummy root for demonstration
        bytes32 sampleMerkleRoot = keccak256(abi.encodePacked("Gang Vesting Merkle Root"));
        console.log("Sample Merkle Root:", vm.toString(sampleMerkleRoot));

        // Deploy GangVesting with MockERC20 as vesting token
        GangVesting vesting = new GangVesting(sampleMerkleRoot, address(mockERC20));
        console.log("GangVesting deployed at:", address(vesting));

        // Set ecosystem address for expired funds
        address ecosystemAddress = deployer; // Using deployer as ecosystem address for simplicity
        vesting.setEcosystemAddress(ecosystemAddress);
        console.log("Ecosystem address set to:", ecosystemAddress);

        // Mint tokens to the deployer
        uint256 totalSupply = 1_000_000_000 * 10 ** 18; // 1B tokens
        mockERC20.mint(deployer, totalSupply);
        console.log("Minted", totalSupply / 10 ** 18, "tokens to deployer");

        // Transfer tokens to the vesting contract
        uint256 vestingAmount = 10_000_000 * 10 ** 18; // 10M tokens for vesting
        mockERC20.approve(address(vesting), vestingAmount);
        mockERC20.transfer(address(vesting), vestingAmount);
        console.log("Transferred", vestingAmount / 10 ** 18, "tokens to vesting contract");

        // Optional: Lock the merkle root to prevent further changes
        // Uncomment the following line if you want to lock the root immediately
        // vesting.lockRoot();
        // console.log("Merkle root locked");

        vm.stopBroadcast();
    }
}
