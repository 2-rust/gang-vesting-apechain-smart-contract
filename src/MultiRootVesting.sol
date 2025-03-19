// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/MerkleProofLib.sol";

// TODO: MODIFY ONCE WE ADD SHADOWS
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title MultiRootVesting
/// @notice Token vesting with multiple merkle roots for different collections
/// @author Rookmate (@0xRookmate)
contract MultiRootVesting is Ownable {
    address public immutable vestingToken;
    address public ecosystemAddress;
    uint32 public immutable expiryWindow = 69 days;
    bool public rootsLocked;

    enum Collection {
        Cat,
        Rat,
        Dog,
        Pigeon,
        BAYC,
        MAYC,
        n1force,
        kanpaiPandas,
        quirkies,
        geezOnApe,
        Crab,
        Team,
        SeedRound,
        StrategicRound,
        CommunityPresale,
        Ecosystem,
        Apechain,
        Liquidity
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

    // Mapping from vesting hash to vesting data
    mapping(bytes32 => Vesting) public vestings;
    // Mapping from Collection to its merkle root
    mapping(Collection => bytes32) public collectionRoots;
    // Mapping from Collection to its NFT address
    mapping(Collection => address) public nftCollections;

    error NotOwner();
    error RootLocked();
    error InvalidAmount();
    error InvalidAddress();
    error AlreadyClaimed();
    error InvalidTimestamp();
    error InvalidCollection();
    error InvalidMerkleProof();
    error EcosystemClaimTooEarly();
    error CollectionNotConfigured();

    event MerkleRootUpdated(Collection indexed collection, bytes32 newRoot);
    event RootsLocked();
    event VestingClaimed(bytes32 indexed vestingId, Collection indexed collection, address recipient, uint256 amount);

    constructor(
        Collection[] memory collections,
        bytes32[] memory roots,
        address[] memory nftAddresses,
        address _vestingToken
    ) {
        _initializeOwner(msg.sender);

        // Ensure collections and roots match the enum length (18)
        if (collections.length != 18 && roots.length != 18) revert InvalidAmount();
        if (nftAddresses.length != 10) revert InvalidAmount();

        vestingToken = _vestingToken;

        // Set up NFT collection addresses
        for (uint256 i = 0; i < 10; ++i) {
            if (nftAddresses[i] == address(0)) revert InvalidAddress();
            nftCollections[Collection(i)] = nftAddresses[i];
        }

        // Set up merkle roots
        for (uint256 i = 0; i < collections.length; ++i) {
            collectionRoots[collections[i]] = roots[i];
        }
    }

    /// @notice Update the merkle root for a specific collection (only if not locked)
    /// @param collection The collection to update
    /// @param newRoot The new merkle root
    function updateMerkleRoot(Collection collection, bytes32 newRoot) external onlyOwner {
        if (rootsLocked) revert RootLocked();
        collectionRoots[collection] = newRoot;
        emit MerkleRootUpdated(collection, newRoot);
    }

    /// @notice Lock all merkle roots permanently
    function lockRoots() external onlyOwner {
        rootsLocked = true;
        emit RootsLocked();
    }

    /// @notice Set the ecosystem address (only owner)
    /// @param _ecosystemAddress The address of the ecosystem
    function setEcosystemAddress(address _ecosystemAddress) external onlyOwner {
        if (rootsLocked) revert RootLocked();
        if (_ecosystemAddress == address(0)) revert InvalidAddress();
        ecosystemAddress = _ecosystemAddress;
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
        if (uint8(collection) >= 18) revert InvalidCollection();

        // Generate leaf from vesting data
        bytes32 leaf = keccak256(abi.encodePacked(collection, tokenId, recipient, totalClaim, start, end));

        // Verify merkle proof against collection root
        if (!MerkleProofLib.verifyCalldata(proof, collectionRoots[collection], leaf)) {
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

        // For NFT collections, use true NFT owner as recipient
        if (uint8(collection) < 10) {
            // TODO: MODIFY ONCE WE ADD SHADOWS
            address owner = IERC721(nftCollections[collection]).ownerOf(tokenId);
            if (owner != vesting.recipient) {
                vesting.recipient = owner;
            }
        }

        SafeTransferLib.safeTransfer(vestingToken, vesting.recipient, amount);

        emit VestingClaimed(leaf, collection, recipient, amount);
    }

    /// @notice Claim unclaimed funds for ecosystem after 69 days from vesting end
    /// @param leaf The vesting identifier
    function claimEcosystemFunds(bytes32 leaf) external {
        Vesting storage vesting = vestings[leaf];

        // Check if 69 days have passed since the end date
        uint256 claimWindow = vesting.end + expiryWindow;
        if (block.timestamp < claimWindow) {
            revert EcosystemClaimTooEarly();
        }

        // Calculate unclaimed amount
        uint256 unclaimedAmount = vesting.totalClaim - vesting.claimed;

        // Ensure there are unclaimed funds
        if (unclaimedAmount == 0) {
            return;
        }

        // Transfer unclaimed funds to the ecosystem address
        SafeTransferLib.safeTransfer(vestingToken, ecosystemAddress, unclaimedAmount);

        // Mark the full amount as claimed
        vesting.claimed = vesting.totalClaim;

        // Emit an event for transparency
        emit VestingClaimed(leaf, vesting.collection, ecosystemAddress, unclaimedAmount);
    }

    /// @notice Internal function to get the vested amount
    /// @param leaf The vesting identifier
    /// @return vesting The vesting struct
    /// @return amount The amount vested
    function calculateVesting(bytes32 leaf) internal view returns (Vesting storage vesting, uint256 amount) {
        vesting = vestings[leaf];

        uint256 start = vesting.start;
        uint256 current = block.timestamp;

        // Early return if vesting hasn't started or if it hasn't passed a day since last claim
        if (current < start || current < (vesting.lastClaim + 1 days)) {
            return (vesting, 0);
        }

        uint256 end = vesting.end;
        uint256 total = vesting.totalClaim;
        uint256 claimed = vesting.claimed;

        // If vesting period is complete, return remaining unclaimed amount
        if (current >= end) {
            unchecked {
                if (current > (end + expiryWindow)) {
                    return (vesting, 0);
                }
                // Safe to use unchecked as totalClaim >= claimed is invariant
                return (vesting, total - claimed);
            }
        }

        // Calculate time-based vesting
        unchecked {
            // These operations cannot overflow due to the previous timestamp checks
            uint256 timeSinceLastClaim = current - vesting.lastClaim;
            uint256 vestingPeriod = end - start;
            amount = (total * timeSinceLastClaim) / vestingPeriod;
        }
    }

    /// @notice Get the vesting details
    /// @param collection The collection type
    /// @param tokenId The tokenId being vested
    /// @param recipient The recipient of the vesting
    /// @param totalClaim The total totalClaim being vested
    /// @param start The start time of the vesting
    /// @param end The end time of the vesting
    /// @return The vesting struct
    function getVesting(
        Collection collection,
        uint256 tokenId,
        address recipient,
        uint256 totalClaim,
        uint32 start,
        uint32 end
    ) external view returns (Vesting memory, uint256 amount) {
        if (uint8(collection) >= 18) revert InvalidCollection();
        bytes32 leaf = keccak256(abi.encodePacked(collection, tokenId, recipient, totalClaim, start, end));
        return calculateVesting(leaf);
    }
}
