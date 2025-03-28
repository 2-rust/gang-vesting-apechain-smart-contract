// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "../src/Gang.sol";
import "../src/GangVesting.sol";

contract DeployGangVesting is Script {
    function run() external {
        string memory rpc = "https://curtis.rpc.caldera.xyz/http";

        vm.createSelectFork(rpc);
        vm.startBroadcast();

        // Deploy ERC20 token
        Gang gang = new Gang();
        console.log("Gang deployed at:", address(gang));

        // Create sample data for Merkle tree (dummy root for demonstration)
        bytes32 sampleMerkleRoot = keccak256(abi.encodePacked("Gutter Vesting Merkle Root"));
        console.log("Sample Merkle Root:", vm.toString(sampleMerkleRoot));

        // Deploy GangVesting with Gang as vesting token
        GangVesting vesting = new GangVesting(sampleMerkleRoot, address(gang));
        console.log("GangVesting deployed at:", address(vesting));

        // Transfer tokens to the vesting contract
        uint256 vestingAmount = gang.MAX_SUPPLY();
        gang.transfer(address(vesting), vestingAmount);
        console.log("Transferred", vestingAmount / 10 ** 18, "tokens to vesting contract");

        vm.stopBroadcast();
    }
}
