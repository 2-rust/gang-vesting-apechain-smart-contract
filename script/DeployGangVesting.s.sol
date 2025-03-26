// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "../src/Gang.sol";
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

        // Deploy ERC20 token
        Gang gang = new Gang();
        console.log("Gang deployed at:", address(gang));

        // Create sample data for Merkle tree (this would be generated off-chain in production)
        // Here we're just creating a dummy root for demonstration
        bytes32 sampleMerkleRoot = keccak256(abi.encodePacked("Gang Vesting Merkle Root"));
        console.log("Sample Merkle Root:", vm.toString(sampleMerkleRoot));

        // Deploy GangVesting with MockERC20 as vesting token
        GangVesting vesting = new GangVesting(sampleMerkleRoot, address(gang));
        console.log("GangVesting deployed at:", address(vesting));

        // Set ecosystem address for expired funds
        address ecosystemAddress = deployer; // Using deployer as ecosystem address for simplicity
        vesting.setEcosystemAddress(ecosystemAddress);
        console.log("Ecosystem address set to:", ecosystemAddress);

        // Transfer tokens to the vesting contract
        uint256 vestingAmount = gang.MAX_SUPPLY();
        gang.transfer(address(vesting), vestingAmount);
        console.log("Transferred", vestingAmount / 10 ** 18, "tokens to vesting contract");

        // Optional: Lock the merkle root to prevent further changes
        // Uncomment the following line if you want to lock the root immediately
        // vesting.lockRoot();
        // console.log("Merkle root locked");

        vm.stopBroadcast();
    }
}
