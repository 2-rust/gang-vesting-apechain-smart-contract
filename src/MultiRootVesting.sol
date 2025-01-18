// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/MerkleProofLib.sol";

/// @title MultiRootVesting
/// @notice Token vesting with multiple merkle roots for different collections
/// @author Rookmate (@0xRookmate)
contract MultiRootVesting is Ownable {
    address immutable vestingToken;

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

    struct MerkleRootData {
        bytes32 root;
        bool locked;
    }

    struct Vesting {
        uint256 totalClaim;
        uint256 claimed;
        uint256 tokenId;
        address recipient;
        uint32 start;
        uint32 end;
        uint32 lastClaim;
        Collection collection;
    }

    // Mapping from Collection to its merkle root data
    mapping(Collection => MerkleRootData) public collectionRoots;
    // Mapping from vesting hash to vesting data
    mapping(bytes32 => Vesting) public vestings;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidTimestamp();
    error NotOwner();
    error InvalidMerkleProof();
    error RootLocked();
    error AlreadyClaimed();
    error InvalidCollection();

    event MerkleRootUpdated(Collection indexed collection, bytes32 newRoot);
    event CollectionRootLocked(Collection indexed collection);
    event VestingClaimed(bytes32 indexed vestingId, Collection indexed collection, address recipient, uint256 amount);

    constructor(Collection[] memory collections, bytes32[] memory roots, address _vestingToken) {
        _initializeOwner(msg.sender);

        vestingToken = _vestingToken;

        if (collections.length != roots.length) revert InvalidAmount();

        for (uint256 i = 0; i < collections.length;) {
            collectionRoots[collections[i]].root = roots[i];
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Update the merkle root for a specific collection (only if not locked)
    /// @param collection The collection to update
    /// @param newRoot The new merkle root
    function updateMerkleRoot(Collection collection, bytes32 newRoot) external onlyOwner {
        if (collectionRoots[collection].locked) revert RootLocked();
        collectionRoots[collection].root = newRoot;
        emit MerkleRootUpdated(collection, newRoot);
    }

    /// @notice Lock the merkle root for a specific collection permanently
    /// @param collection The collection to lock
    function lockRoot(Collection collection) external onlyOwner {
        collectionRoots[collection].locked = true;
        emit CollectionRootLocked(collection);
    }

    /// @notice Get the merkle root for a specific collection
    /// @param collection The collection to query
    /// @return root The merkle root
    /// @return locked Whether the root is locked
    function getCollectionRoot(Collection collection) external view returns (bytes32 root, bool locked) {
        if (uint8(collection) >= 12) revert InvalidCollection();
        MerkleRootData memory rootData = collectionRoots[collection];
        return (rootData.root, rootData.locked);
    }

    /// @notice Claim vested tokens with merkle proof
    /// @param proof Merkle proof to validate the claim
    /// @param collection The collection type
    /// @param tokenId The tokenId being vested
    /// @param recipient The recipient of the vesting
    /// @param totalClaim The total amount being vested
    /// @param start The start time of the vesting
    /// @param end The end time of the vesting
    function claim(
        bytes32[] calldata proof,
        Collection collection,
        uint256 tokenId,
        address recipient,
        uint256 totalClaim,
        uint32 start,
        uint32 end
    ) external {
        // Check collection validity
        if (uint8(collection) >= 12) revert InvalidCollection();

        // Generate leaf from vesting data
        bytes32 leaf = keccak256(abi.encodePacked(collection, tokenId, recipient, totalClaim, start, end));

        // Verify merkle proof against collection root
        if (!MerkleProofLib.verifyCalldata(proof, collectionRoots[collection].root, leaf)) {
            revert InvalidMerkleProof();
        }

        // Get or initialize vesting
        Vesting storage vesting = vestings[leaf];
        if (vesting.totalClaim == 0) {
            // Initialize vesting if first claim
            vesting.totalClaim = totalClaim;
            vesting.tokenId = tokenId;
            vesting.recipient = recipient;
            vesting.start = start;
            vesting.end = end;
            vesting.lastClaim = start;
            vesting.collection = collection;
        }

        // Calculate vested amount
        (, uint256 amount) = calculateVesting(leaf);
        if (amount == 0) revert AlreadyClaimed();

        // Update vesting state
        vesting.lastClaim = uint32(block.timestamp);
        unchecked {
            vesting.claimed += amount;
        }

        SafeTransferLib.safeTransfer(vestingToken, vesting.recipient, amount);

        emit VestingClaimed(leaf, collection, recipient, amount);
    }

    /// @notice Internal function to get the vested amount
    /// @param vestingId The vesting identifier
    /// @return vesting The vesting struct
    /// @return amount The amount vested
    function calculateVesting(bytes32 vestingId) internal view returns (Vesting storage vesting, uint256 amount) {
        vesting = vestings[vestingId];

        uint256 vestingStart = vesting.start;
        if (block.timestamp < vestingStart) return (vesting, 0);

        uint256 vestingEnd = vesting.end;
        uint256 vestingTotal = vesting.totalClaim;
        uint256 vestingClaimed = vesting.claimed;
        if (block.timestamp >= vestingEnd) {
            return (vesting, (vestingTotal - vestingClaimed));
        }

        uint256 timeSinceLastClaim = block.timestamp - vesting.lastClaim;
        uint256 vestingPeriod = vestingEnd - vestingStart;
        amount = (vestingTotal * timeSinceLastClaim) / vestingPeriod;
    }

    /// @notice Get the vesting details
    /// @param collection The collection type
    /// @param tokenId The tokenId being vested
    /// @param recipient The recipient of the vesting
    /// @param amount The total amount being vested
    /// @param start The start time of the vesting
    /// @param end The end time of the vesting
    /// @return The vesting struct
    function getVesting(
        Collection collection,
        address tokenId,
        address recipient,
        uint256 amount,
        uint32 start,
        uint32 end
    ) external view returns (Vesting memory) {
        if (uint8(collection) >= 12) revert InvalidCollection();
        bytes32 leaf = keccak256(abi.encodePacked(collection, tokenId, recipient, amount, start, end));
        return vestings[leaf];
    }
}
