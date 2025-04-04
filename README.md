## Working with GangVesting

GangVesting is a simpler version with a single merkle root for all vesting schedules.

### Deployment

Deploy the GangVesting contract with the following constructor parameters:
```solidity
constructor(bytes32 _merkleRoot, address _vestingToken)
```

Required setup:
1. `_merkleRoot`: The merkle root for all vesting schedules
2. `_vestingToken`: Address of the deployed Gang token

### Post-Deployment Setup

1. Transfer required Gang tokens to the GangVesting contract
2. Set ecosystem address using `setEcosystemAddress()`
3. Update the merkle root if needed using `updateMerkleRoot()`
4. Once configuration is final, call `lockRoot()` to permanently lock the setup

### Claiming Vested Tokens

Users can claim their vested tokens using:
```solidity
function claim(
    bytes32[] calldata proof,
    Collection collection,
    address recipient,
    uint256 totalClaim,
    uint32 start,
    uint32 end
) external
```
Key considerations:
- Generate valid merkle proofs for each claim
- Claims must be made within the vesting period plus 69-day expiry window
- Tokens vest linearly between start and end times
- Minimum 1 day between claims

### Ecosystem Claims
After the 69-day expiry window, unclaimed tokens can be recovered:
```solidity
function claimEcosystemFunds(bytes32 leaf) external
```

### Vesting Queries
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

### Generating Merkle Trees

Use the provided JavaScript example to generate merkle trees for GangVesting:

```javascript
// Define vesting data
const vestingData = [
  {
    collection: 0, // Collection.Cat = 0
    recipient: '0x77f2Dc5d302e71Ab6645622FAB27123E52e3e035',
    totalClaim: parseEther('100'),
    start: timestamp,
    end: timestamp + (365 * 24 * 60 * 60) // timestamp + 365 days
  }
];

// Create leaves for the Merkle tree
const leaves = vestingData.map(vesting => {
  return keccak256(encodePacked(
    ['uint8', 'address', 'uint256', 'uint32', 'uint32'],
    [
      vesting.collection,
      vesting.recipient,
      vesting.totalClaim,
      BigInt(vesting.start),
      BigInt(vesting.end)
    ]
  ));
});

// Create the Merkle tree and get the root
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const merkleRoot = merkleTree.getHexRoot();
```

## Testing

### Running Tests

Run tests using Foundry:

```bash
forge test
```

To run a specific test:

```bash
forge test --match-test testClaimVesting -vv
```

### Testing with Real Data

1. Generate a merkle tree and root:

```bash
node MerkleTreeGenerationExample.js
```

Sample output:
```
ApeChain Testnet Current Block: {
  number: 16699306n,
  timestamp: 1742817422n,
  date: '2025-03-24T11:57:02.000Z'
}
Timestamp from 2 days ago: 1742644628
Date from 2 days ago: 2025-03-22T11:57:08.000Z
Merkle Root: 0x4fda1c3907cb51b1ef808011619b06a909ad419484fb68b66c53315e3fd4bbd9
Merkle Proof for first vesting: [
  '0x86d90af917e1de28b530e664df266fc7081c9b791bc19acdef13d791950df786',
  '0x442e396fb9684817865b881f0a7bded188ddf389f6359235c4441b3eeddb4b2f'
]
```

2. Send a claim transaction using Cast:

```bash
cast send CONTRACT_ADDRESS \
"claim(bytes32[],uint8,address,uint256,uint32,uint32)" \
"[PROOF_LEAVES]" \
0 \
CLAIM_ADDRESS \
TOTAL_AMOUNT \
START_TS \
END_TS \
--rpc-url https://rpc.curtis.apechain.com \
--private-key $PRIVATE_KEY
```

## Important Notes

1. Each claim requires a valid merkle proof matching the collection's root
2. NFT-based vestings automatically redirect to current NFT owners (in MultiRootVesting)
3. Claims must be made at least 1 day apart
4. Vesting expires 69 days after end date
5. Once roots are locked, they cannot be modified
6. Collection enum must be within valid range (0-11 for MultiRootVesting, 0-17 for GangVesting)

## Merkle Tree Requirements

The merkle tree leaves should be constructed as:

For MultiRootVesting:
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

For GangVesting:
```solidity
bytes32 leaf = keccak256(abi.encodePacked(
    uint8(collection),
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
