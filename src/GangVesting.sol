// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/MerkleProofLib.sol";

/// @title GangVesting
/// @notice Token vesting with a single merkle root
/// @author Rookmate
contract GangVesting is Ownable {
    address public immutable vestingToken;
    address public ecosystemAddress;
    uint32 public constant expiryWindow = 69 days;
    bytes32 public merkleRoot;
    bool public rootLocked;
    uint256 public totalClaimed;

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
        chimpers,
        chimpersGen,
        reGenerates,
        Grab,
        Team,
        SeedRound,
        CommunityPresale,
        Ecosystem,
        Apechain,
        Liquidity
    }

    struct Vesting {
        uint256 totalClaim;
        uint256 claimed;
        address recipient;
        uint32 start;
        uint32 end;
        uint32 lastClaim;
        Collection collection;
    }

    // Mapping from vesting hash to vesting data
    mapping(bytes32 => Vesting) public vestings;

    error RootIsLocked();
    error InvalidAmount();
    error InvalidAddress();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error ArrayLengthMustMatch();
    error EcosystemClaimTooEarly();

    event MerkleRootUpdated(bytes32 newRoot);
    event RootLocked();
    event VestingClaimed(bytes32 indexed vestingId, address recipient, uint256 amount);

    constructor(bytes32 _merkleRoot, address _vestingToken) {
        _initializeOwner(msg.sender);
        merkleRoot = _merkleRoot;
        vestingToken = _vestingToken;
    }

    /// @notice Update the merkle root (only if not locked)
    /// @param newRoot The new merkle root
    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        if (rootLocked) revert RootIsLocked();
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    /// @notice Lock the merkle root permanently
    function lockRoot() external onlyOwner {
        if (rootLocked) revert RootIsLocked();
        rootLocked = true;
        emit RootLocked();
    }

    /// @notice Set the ecosystem address (only owner)
    /// @param _ecosystemAddress The address of the ecosystem
    function setEcosystemAddress(address _ecosystemAddress) external onlyOwner {
        if (rootLocked) revert RootIsLocked();
        if (_ecosystemAddress == address(0)) revert InvalidAddress();
        ecosystemAddress = _ecosystemAddress;
    }

    /// @notice Claim vested tokens with merkle proof
    /// @param proof Merkle proof to validate the claim
    /// @param collection The collection associated with the vesting
    /// @param recipient The recipient of the vesting
    /// @param totalClaim The total amount being vested
    /// @param start The start time of the vesting
    /// @param end The end time of the vesting
    function claim(
        bytes32[] calldata proof,
        Collection collection,
        address recipient,
        uint256 totalClaim,
        uint32 start,
        uint32 end
    ) external {
        if (totalClaim == 0) revert InvalidAmount();
        if (start >= end) revert InvalidAmount();

        // Generate leaf from vesting data
        bytes32 leaf = keccak256(abi.encodePacked(uint8(collection), recipient, totalClaim, start, end));

        // Verify merkle proof against root
        if (!MerkleProofLib.verifyCalldata(proof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // Get or initialize vesting
        Vesting storage vesting = vestings[leaf];
        if (vesting.totalClaim == 0) {
            // Initialize vesting if first claim
            vesting.totalClaim = totalClaim;
            vesting.collection = collection;
            vesting.recipient = recipient;
            vesting.start = start;
            vesting.end = end;
            vesting.lastClaim = start;
        }

        // Calculate vested amount
        (, uint256 amount) = _calculateVesting(leaf, true);
        if (amount == 0) revert AlreadyClaimed();

        // Update vesting state
        vesting.lastClaim = uint32(block.timestamp);
        unchecked {
            vesting.claimed += amount;
            totalClaimed += amount;
        }

        // Transfer tokens to recipient
        SafeTransferLib.safeTransfer(vestingToken, recipient, amount);

        emit VestingClaimed(leaf, recipient, amount);
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
        emit VestingClaimed(leaf, ecosystemAddress, unclaimedAmount);
    }

    /// @notice Internal function to get the vested amount
    /// @param leaf The vesting identifier
    /// @return vesting The vesting struct
    /// @return amount The amount vested
    function _calculateVesting(bytes32 leaf, bool isClaim)
        internal
        view
        returns (Vesting storage vesting, uint256 amount)
    {
        vesting = vestings[leaf];

        uint256 start = vesting.start;
        uint256 current = block.timestamp;

        // Early return if vesting hasn't started
        if (current < start) {
            return (vesting, 0);
        }

        // If it hasn't passed a day since last claim
        if (isClaim && current < (vesting.lastClaim + 1 days)) {
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
            uint256 timeSinceStart = current - start;
            uint256 vestingPeriod = end - start;
            uint256 vestedSoFar = (total * timeSinceStart) / vestingPeriod;
            amount = vestedSoFar - claimed;
        }
    }

    /// @notice Get the vesting details for a single vesting
    /// @param collection The collection associated with the vesting
    /// @param recipient The recipient of the vesting
    /// @param totalClaim The total totalClaim being vested
    /// @param start The start time of the vesting
    /// @param end The end time of the vesting
    /// @return The vesting struct and current claimable amount
    function getVesting(Collection collection, address recipient, uint256 totalClaim, uint32 start, uint32 end)
        external
        view
        returns (Vesting memory, uint256 amount)
    {
        bytes32 leaf = keccak256(abi.encodePacked(uint8(collection), recipient, totalClaim, start, end));
        return _calculateVesting(leaf, false);
    }

    /// @notice Get vesting details for multiple vestings at once
    /// @param collections Array of collections
    /// @param recipients Array of recipients
    /// @param totalClaims Array of total claims
    /// @param starts Array of start times
    /// @param ends Array of end times
    /// @return vestingInfo Array of vesting structs
    /// @return amounts Array of claimable amounts
    function getVestingBatch(
        Collection[] calldata collections,
        address[] calldata recipients,
        uint256[] calldata totalClaims,
        uint32[] calldata starts,
        uint32[] calldata ends
    ) external view returns (Vesting[] memory vestingInfo, uint256[] memory amounts) {
        // Check that all arrays have the same length
        uint256 length = collections.length;
        if (
            recipients.length != length || totalClaims.length != length || starts.length != length
                || ends.length != length
        ) revert ArrayLengthMustMatch();

        vestingInfo = new Vesting[](length);
        amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 leaf =
                keccak256(abi.encodePacked(uint8(collections[i]), recipients[i], totalClaims[i], starts[i], ends[i]));
            (Vesting storage info, uint256 amount) = _calculateVesting(leaf, false);

            // Copy storage struct to memory
            vestingInfo[i] = Vesting({
                totalClaim: info.totalClaim,
                claimed: info.claimed,
                recipient: info.recipient,
                start: info.start,
                end: info.end,
                lastClaim: info.lastClaim,
                collection: info.collection
            });

            amounts[i] = amount;
        }
    }
}
