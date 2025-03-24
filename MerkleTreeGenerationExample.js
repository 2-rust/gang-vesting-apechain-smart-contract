const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { parseEther, encodePacked, createPublicClient, http } = require('viem');
const { apechain } = require('viem/chains');

async function main() {
  // Create a viem client for ApeChain testnet
  const client = createPublicClient({
    chain: {
      ...apechain,
      id: 33111, // ApeChain testnet chain ID
      name: 'ApeChain Testnet',
      rpcUrls: {
        default: {
          http: ['https://rpc.curtis.apechain.com'],
        },
        public: {
          http: ['https://rpc.curtis.apechain.com'],
        },
      },
    },
    transport: http(),
  });

  try {
    // Get the latest block from ApeChain testnet
    const block = await client.getBlock();
    console.log('ApeChain Testnet Current Block:', {
      number: block.number,
      timestamp: block.timestamp,
      date: new Date(Number(block.timestamp) * 1000).toISOString(),
    });

    // Calculate timestamp from 2 days ago
    const twoDaysAgo = Math.floor(Date.now() / 1000) - (2 * 24 * 60 * 60);
    console.log('Timestamp from 2 days ago:', twoDaysAgo);
    console.log('Date from 2 days ago:', new Date(twoDaysAgo * 1000).toISOString());

    // Create vesting data with start time set to 2 days ago
    const vestingData = [
      {
        collection: 0, // Collection.Cat = 0
        recipient: '0x77f2Dc5d302e71Ab6645622FAB27123E52e3e035',
        totalClaim: parseEther('100'),
        start: twoDaysAgo, // 2 days ago
        end: twoDaysAgo + (365 * 24 * 60 * 60) // 2 days ago + 365 days
      },
      {
        collection: 1, // Collection.Rat = 1
        recipient: '0x77f2Dc5d302e71Ab6645622FAB27123E52e3e035',
        totalClaim: parseEther('200'),
        start: twoDaysAgo,
        end: twoDaysAgo + (365 * 24 * 60 * 60)
      },
      {
        collection: 2, // Collection.Dog = 2
        recipient: '0x77f2Dc5d302e71Ab6645622FAB27123E52e3e035',
        totalClaim: parseEther('300'),
        start: twoDaysAgo + (30 * 24 * 60 * 60), // 2 days ago + 30 days
        end: twoDaysAgo + (395 * 24 * 60 * 60) // 2 days ago + 395 days
      }
    ];

    // Create leaves for the Merkle tree
    const leaves = vestingData.map(vesting => {
      // Match the same encoding as in the Solidity contract
      // uint8(collection), recipient, totalClaim, start, end
      const encodedData = encodePacked(
        ['uint8', 'address', 'uint256', 'uint32', 'uint32'],
        [
          vesting.collection,
          vesting.recipient,
          vesting.totalClaim,
          BigInt(vesting.start),
          BigInt(vesting.end)
        ]
      );

      // Hash the encoded data using keccak256
      return keccak256(encodedData);
    });

    // Create the Merkle tree
    const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });

    // Get the Merkle root
    const merkleRoot = merkleTree.getHexRoot();
    console.log('Merkle Root:', merkleRoot);

    // Example of generating a proof for the first vesting data
    const hexProof = merkleTree.getHexProof(leaves[0]);
    console.log('Merkle Proof for first vesting:', hexProof);

    // Display the claim data that would be used in the contract
    console.log('Claim data for first vesting that would be passed to contract:');
    console.log({
      proof: hexProof,
      collection: vestingData[0].collection,
      recipient: vestingData[0].recipient,
      totalClaim: vestingData[0].totalClaim.toString(),
      start: vestingData[0].start,
      end: vestingData[0].end
    });
  } catch (error) {
    console.error('Error connecting to ApeChain testnet:', error);
  }
}

main();
