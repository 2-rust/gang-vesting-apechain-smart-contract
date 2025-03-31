// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "../src/Gang.sol";
import "../src/GangVesting.sol";

// TESTNET DEPLOYMENT
// forge script script/DeployGangVesting.s.sol --ledger --verify --verifier blockscout --verifier-url https://curtis.explorer.caldera.xyz/api --chain-id 33111 --broadcast  --mnemonic-indexes 1 --rpc-url https://curtis.rpc.caldera.xyz/http
// MAINNET DEPLOYMENT
// forge script script/DeployGangVesting.s.sol --ledger --verify --etherscan-api-key $APESCAN_API_KEY --verifier-url https://api.apescan.io/api --chain-id 33139 --mnemonic-indexes 1 --broadcast --rpc-url https://rpc.apechain.com
// MAINNET ADDRESSES
// Gutter Token: https://apescan.io/address/0x28d9428716c2f6e566766dc8f5f56c1af43042b7
// Vesting: https://apescan.io/address/0xf5918f8cf2e6d9dfd78ef15a7cacfba97a7e1e1b

contract DeployGangVesting is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy ERC20 token
        Gang gang = new Gang();
        console.log("Gang deployed at:", address(gang));

        // Final Merkle Root
        bytes32 merkleRoot = 0x69a5080be5836b60bd3c9129814e9bdb67db2ec8986d146a9d9efb24506c222c;
        console.log("Merkle Root:", vm.toString(merkleRoot));

        // Deploy GangVesting with Gang as vesting token
        GangVesting vesting = new GangVesting(merkleRoot, address(gang));
        console.log("GangVesting deployed at:", address(vesting));

        // Transfer tokens to the vesting contract
        uint256 vestingAmount = gang.MAX_SUPPLY();
        gang.transfer(address(vesting), vestingAmount);
        console.log("Transferred", vestingAmount / 10 ** 18, "tokens to vesting contract");

        vm.stopBroadcast();
    }
}
