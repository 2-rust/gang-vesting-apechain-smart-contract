# MultiRootVesting Integration Guide

## Prerequisites

1. The Gang ERC20 token contract address
2. NFT collection addresses for Cat, Rat, Dog, Pigeon, and Crab collections
3. Merkle roots for all supported collection types:
   - NFT Collections (Cat, Rat, Dog, Pigeon, Crab)
   - Team
   - SeedRound
   - StrategicRound
   - CommunityPresale
   - Ecosystem
   - Apechain
   - Liquidity

## Contract Deployment

### Step 1: Deploy Gang Token
First, deploy the Gang token contract. The deployer will receive the total supply of 1 billion GANG tokens (with 18 decimals).

### Step 2: Deploy MultiRootVesting
The MultiRootVesting contract requires the following constructor parameters:
```solidity
constructor(
    Collection[] memory collections,
    bytes32[] memory roots,
    address[] memory nftAddresses,
    address _vestingToken
)
```

Required setup:
1. `collections`: Array of Collection enum values for initial setup
2. `roots`: Corresponding merkle roots for each collection
3. `nftAddresses`: Exactly 5 NFT collection addresses (Cat, Rat, Dog, Pigeon, Crab)
4. `_vestingToken`: Address of the deployed Gang token

## Post-Deployment Setup

1. Transfer required Gang tokens to the MultiRootVesting contract
2. Set ecosystem address using `setEcosystemAddress()`
3. Update any merkle roots if needed using `updateMerkleRoot()`
4. Once configuration is final, call `lockRoots()` to permanently lock the setup

## Integration Points

### 1. Claiming Vested Tokens
Users can claim their vested tokens using:
```solidity
function claim(
    bytes32[] calldata proof,
    Collection collection,
    uint256 tokenId,
    address recipient,
    uint256 totalClaim,
    uint32 start,
    uint32 end
) external
```

Key considerations:
- Generate valid merkle proofs for each claim
- For NFT collections (0-4), the actual recipient will be the current NFT owner
- Claims must be made within the vesting period plus 69-day expiry window
- Tokens vest linearly between start and end times
- Minimum 1 day between claims

### 2. Ecosystem Claims
After the 69-day expiry window, unclaimed tokens can be recovered:
```solidity
function claimEcosystemFunds(bytes32 leaf) external
```

### 3. Vesting Queries
Check vesting details and claimable amounts:
```solidity
function getVesting(
    Collection collection,
    uint256 tokenId,
    address recipient,
    uint256 totalClaim,
    uint32 start,
    uint32 end
) external view returns (Vesting memory, uint256 amount)
```

## Important Notes

1. Each claim requires a valid merkle proof matching the collection's root
2. NFT-based vestings automatically redirect to current NFT owners
3. Claims must be made at least 1 day apart
4. Vesting expires 69 days after end date
5. Once roots are locked, they cannot be modified
6. Collection enum must be within valid range (0-11)

## Merkle Tree Requirements

The merkle tree leaves should be constructed as:
```solidity
bytes32 leaf = keccak256(abi.encodePacked(
    collection,
    tokenId,
    recipient,
    totalClaim,
    start,
    end
));
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
