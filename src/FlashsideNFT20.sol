// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// ============ Interfaces ============

// ERC721
interface IERC721 {
  /// @notice Set transfer approval for operator
  function setApprovalForAll(address operator, bool approved) external;
  /// @notice Transfer NFT
  function transferFrom(address from, address to, uint256 tokenId) external;
}

// Otherside Land NFT
interface OthersideLand is IERC721 {
  /// @notice Claim land for BAYC (alpha) and MAYC (beta)
  function nftOwnerClaimLand(
    uint256[] calldata alphaTokenIds, 
    uint256[] calldata betaTokenIds
  ) external;
  /// @notice Check if claim is active
  function claimableActive() external returns (bool);
}

/// @title FlashsideNFT20
/// @author Anish Agnihotri
/// @notice Flashloan BAYC from NFT20 and claim Land NFT
contract FlashsideNFT20 {
  // ============ Immutable storage ============

  /// @dev Contract owner
  address internal immutable OWNER;
  /// @dev Otherside land contract
  OthersideLand internal immutable LAND;

  // ============ Constructor ============

  /// @notice Creates a new FlashsideNFT20 contract
  /// @param _BAYC address of BAYC token
  /// @param _BAYC20 address of BAYC NFT20 pair token
  /// @param _LAND address of Otherside land token
  constructor(address _BAYC, address _BAYC20, address _LAND) {
    // Setup contract owner
    OWNER = msg.sender;
    // Approve BAYC20 pair to spend BAYC balance (to clawback after flashloan)
    IERC721(_BAYC).setApprovalForAll(_BAYC20, true);
    // Setup Otherside land contract
    LAND = OthersideLand(_LAND);
  }

  // ============ Functions ============

  /// @notice Executes flashloan
  function executeOperation(
    uint256[] calldata _ids,
    uint256[] calldata _amounts,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    // Check if land claim is claimable
    bool landClaimActive = LAND.claimableActive();
    // If claim not active, revert
    if (!landClaimActive) revert("Land claim not active");

    // Setup MAYC claim array
    uint256[] memory beta;
    // Claim land from BAYC
    LAND.nftOwnerClaimLand(_ids, beta);
    // Return true to satisfy flash loan requirements
    return true;
  }

  /// @notice Allow withdrawing NFTs to owner address
  /// @param _ids to withdraw
  function withdrawLand(uint256[] calldata _ids) external {
    // Withdraw land to owner
    for (uint256 i = 0; i < _ids.length; i++) {
      // Send from this contract to owner
      LAND.transferFrom(address(this), OWNER, _ids[i]);
    }
  }

  /// @notice Accept ERC721 tokens
  function onERC721Received(
    address _operator,
    address _from,
    uint256 _tokenId,
    bytes calldata _data
  ) external returns (bytes4) {
    // IERC721.onERC721Received.selector
    return 0x150b7a02;
  }
}
