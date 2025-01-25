// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./MultiRootVestingTestBase.sol";

// Extended IERC721 interface with required functions
interface IERC721Extended {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract MultiRootVestingNFTOwnershipTest is MultiRootVestingTestBase {
    address newOwner = address(0x6);
    uint256 constant NFT_ID = 1;
    uint256 constant VESTING_AMOUNT = 100e18;
    uint32 vestingStart;
    uint32 vestingEnd;
    bytes32[] proof;

    function setUp() public override {
        super.setUp();

        vestingStart = uint32(block.timestamp);
        vestingEnd = uint32(block.timestamp + 365 days);

        // Get proof for NFT_ID 1 owned by user1
        proof = merkle.getProof(catLeaves, 0);
    }

    function testTransferNFTBeforeClaim() public {
        // Transfer NFT before any claims
        vm.prank(user1);
        catNFT.transferFrom(user1, newOwner, NFT_ID);

        // Warp to middle of vesting period
        vm.warp(vestingStart + 182 days);

        // New owner should be able to claim
        vm.prank(newOwner);
        vestContract.claim(
            proof,
            MultiRootVesting.Collection.Cat,
            NFT_ID,
            user1, // Original recipient
            VESTING_AMOUNT,
            vestingStart,
            vestingEnd
        );

        // Verify tokens went to new owner
        assertGt(token.balanceOf(newOwner), 0);
        assertEq(token.balanceOf(user1), 0);
    }

    function testTransferNFTBetweenClaims() public {
        // Warp to 25% of vesting period
        vm.warp(vestingStart + 91 days);

        // First claim by original owner
        vm.prank(user1);
        vestContract.claim(
            proof, MultiRootVesting.Collection.Cat, NFT_ID, user1, VESTING_AMOUNT, vestingStart, vestingEnd
        );

        uint256 user1Balance = token.balanceOf(user1);

        // Transfer NFT
        vm.prank(user1);
        catNFT.transferFrom(user1, newOwner, NFT_ID);

        // Warp to 75% of vesting period
        vm.warp(vestingStart + 273 days);

        // New owner claims remaining tokens
        vm.prank(newOwner);
        vestContract.claim(
            proof,
            MultiRootVesting.Collection.Cat,
            NFT_ID,
            user1, // Original recipient
            VESTING_AMOUNT,
            vestingStart,
            vestingEnd
        );

        // Verify balances
        assertGt(token.balanceOf(newOwner), 0);
        assertEq(token.balanceOf(user1), user1Balance); // Original owner's balance shouldn't change
        assertApproxEqRel(
            token.balanceOf(user1) + token.balanceOf(newOwner),
            VESTING_AMOUNT * 75 / 100, // ~75% of total should be claimed
            0.01e18 // 1% tolerance
        );
    }

    function testMultipleTransfersSameDay() public {
        // Warp to middle of vesting period
        vm.warp(vestingStart + 182 days);

        // Transfer NFT multiple times in the same day
        vm.prank(user1);
        catNFT.transferFrom(user1, newOwner, NFT_ID);

        vm.prank(newOwner);
        catNFT.transferFrom(newOwner, user2, NFT_ID);

        vm.prank(user2);
        catNFT.transferFrom(user2, user3, NFT_ID);

        // Final owner should be able to claim
        vm.prank(user3);
        vestContract.claim(
            proof,
            MultiRootVesting.Collection.Cat,
            NFT_ID,
            user1, // Original recipient
            VESTING_AMOUNT,
            vestingStart,
            vestingEnd
        );

        // Verify only final owner received tokens
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(newOwner), 0);
        assertEq(token.balanceOf(user2), 0);
        assertGt(token.balanceOf(user3), 0);
    }

    function testTransferDuringClaimTransaction() public {
        // Warp to middle of vesting period
        vm.warp(vestingStart + 182 days);

        // Create a contract that will transfer the NFT during the claim
        NFTTransferExploit exploiter = new NFTTransferExploit(address(catNFT), address(vestContract));

        // Transfer NFT to exploiter contract
        vm.prank(user1);
        catNFT.transferFrom(user1, address(exploiter), NFT_ID);

        // Attempt claim with transfer in same transaction
        vm.prank(address(exploiter));
        exploiter.claimAndTransfer(proof, NFT_ID, user1, VESTING_AMOUNT, vestingStart, vestingEnd);

        // Verify tokens went to correct owner
        assertGt(token.balanceOf(newOwner), 0);
        assertEq(token.balanceOf(address(exploiter)), 0);
    }
}

// Helper contract to test NFT transfers during claim transaction
contract NFTTransferExploit {
    IERC721Extended public nft;
    MultiRootVesting public vestingContract;

    constructor(address _nft, address _vestingContract) {
        nft = IERC721Extended(_nft);
        vestingContract = MultiRootVesting(_vestingContract);
    }

    function claimAndTransfer(
        bytes32[] calldata proof,
        uint256 tokenId,
        address recipient,
        uint256 amount,
        uint32 start,
        uint32 end
    ) external {
        // Transfer NFT before internal ownerOf check
        nft.transferFrom(address(this), address(0x6), tokenId);

        // Attempt claim
        vestingContract.claim(proof, MultiRootVesting.Collection.Cat, tokenId, recipient, amount, start, end);
    }
}
