import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { ethers } from "ethers";

// Define the Collection enum to match the contract
enum Collection {
  Cat,
  Rat,
  Dog,
  Pigeon,
  Crab,
  Team,
  SeedRound,
  StrategicRound,
  CommunityPresale,
  Ecosystem,
  Apechain,
  Liquidity
}

interface VestingData {
  collection: Collection;
  tokenId: bigint;
  recipient: string;
  totalClaim: bigint;
  start: number;
  end: number;
}

export class VestingMerkleGenerator {
  private trees: Map<Collection, StandardMerkleTree<any[]>> = new Map();

  /**
   * Generate merkle trees for each collection
   * @param vestingDataByCollection Map of collection to their vesting data
   * @returns Map of collection to their merkle roots
   */
  generateMerkleRoots(vestingDataByCollection: Map<Collection, VestingData[]>): Map<Collection, string> {
    const roots = new Map<Collection, string>();

    for (const [collection, vestingData] of vestingDataByCollection.entries()) {
      // Format the data for the merkle tree
      const values = vestingData.map(data => [
        data.collection,
        data.tokenId,
        data.recipient,
        data.totalClaim,
        data.start,
        data.end
      ]);

      // Create the merkle tree
      const tree = StandardMerkleTree.of(values, [
        "uint8",    // collection
        "uint256",  // tokenId
        "address",  // recipient
        "uint256",  // totalClaim
        "uint32",   // start
        "uint32"    // end
      ]);

      // Store tree for later proof generation
      this.trees.set(collection, tree);

      // Store the root
      roots.set(collection, tree.root);
    }

    return roots;
  }

  /**
   * Generate proof for a specific vesting claim
   * @param collection The collection type
   * @param vestingData The vesting data to generate proof for
   * @returns The merkle proof
   */
  generateProof(collection: Collection, vestingData: VestingData): string[] {
    const tree = this.trees.get(collection);
    if (!tree) {
      throw new Error(`No merkle tree found for collection ${Collection[collection]}`);
    }

    const targetValue = [
      vestingData.collection,
      vestingData.tokenId,
      vestingData.recipient,
      vestingData.totalClaim,
      vestingData.start,
      vestingData.end
    ];

    // Find the leaf in the tree and generate proof
    for (const [i, v] of tree.entries()) {
      if (JSON.stringify(v) === JSON.stringify(targetValue)) {
        return tree.getProof(i);
      }
    }

    throw new Error("Vesting data not found in tree");
  }
}

// Example usage
async function main() {
  // Sample vesting data for different collections
  const vestingDataByCollection = new Map<Collection, VestingData[]>();

  // NFT Collection (Cat) example
  vestingDataByCollection.set(Collection.Cat, [
    {
      collection: Collection.Cat,
      tokenId: BigInt(1),
      recipient: "0x1234...",
      totalClaim: ethers.parseEther("1000"), // 1000 tokens
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year
    },
    // Add more Cat NFT vesting entries...
  ]);

  // Team vesting example
  vestingDataByCollection.set(Collection.Team, [
    {
      collection: Collection.Team,
      tokenId: BigInt(0), // Not used for non-NFT collections
      recipient: "0x5678...",
      totalClaim: ethers.parseEther("5000000"), // 5M tokens
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60) // 2 years
    },
    // Add more team vesting entries...
  ]);

  // Generate merkle trees and get roots
  const generator = new VestingMerkleGenerator();
  const roots = generator.generateMerkleRoots(vestingDataByCollection);

  // Example: Generate proof for a specific claim
  const catVesting = vestingDataByCollection.get(Collection.Cat)![0];
  const proof = generator.generateProof(Collection.Cat, catVesting);

  // Log results
  console.log("Merkle Roots:");
  for (const [collection, root] of roots.entries()) {
    console.log(`${Collection[collection]}: ${root}`);
  }

  console.log("\nExample Proof for Cat NFT #1:");
  console.log(proof);

  // Format constructor parameters for MultiRootVesting
  const collections = Array.from(roots.keys());
  const rootsArray = Array.from(roots.values());

  console.log("\nConstructor Parameters:");
  console.log("collections:", collections);
  console.log("roots:", rootsArray);
}

// Run the example
main().catch(console.error);
