// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// ============ Imports ============

import "forge-std/Vm.sol"; // Vm
import "forge-std/Test.sol"; // Forge test
import "../src/FlashsideNFT20.sol"; // FlashsideNFT20

/// ============ Interfaces ============

// Extend land contract
interface OthersideLandExtended is OthersideLand {
  /// @notice Allows operator to flip claimable state
  function flipClaimableState() external;
  /// @notice Gets contract operator
  function operator() external returns (address);
  /// @notice Get balance of address
  function balanceOf(address owner) external returns (uint256);
}

// NFT20 pair
interface INFT20Pair {
  // Execute flashloan
  function flashLoan(
    uint256[] calldata _ids,
    uint256[] calldata _amounts,
    address _operator,
    bytes calldata _params
  ) external;
}

/// @title FlashsideNFT20Test
/// @author Anish Agnihotri
/// @notice Test FlashsideNFT20
contract FlashsideNFT20Test is Test {
  // ============  Storage ============

  /// @notice Cheatcodes
  Vm public VM;
  /// @notice NFT20 BAYC pair
  INFT20Pair public BAYC20;
  /// @notice FlashsideNFT20 contract
  FlashsideNFT20 public FLASHSIDE;
  /// @notice Land contract
  OthersideLandExtended public LAND;

  // ============  Functions ============

  /// @notice Setup tests
  function setUp() public {
    // Setup cheatcodes
    VM = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    // Setup Otherside land contract
    LAND = OthersideLandExtended(0x34d85c9CDeB23FA97cb08333b511ac86E1C4E258);
    // Setup NFT20 BAYC pair contract
    BAYC20 = INFT20Pair(0x7C15561590FC9eB063B3803b55165633eEf207ec);
    // Initialize FlashsideNFT20
    FLASHSIDE = new FlashsideNFT20(
      0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D, // BAYC
      address(BAYC20), // BAYC20 pair
      address(LAND) // Otherside land
    );
  }

  /// @notice Test claiming land when claimable is toggled true
  function testClaimLandClaimable() public {
    // Get claimable status
    bool isClaimable = LAND.claimableActive();
    // Toggle claimable
    if (!isClaimable) {
      // Get contract operator
      address landOperator = LAND.operator();
      // Mock operator for next call
      VM.prank(landOperator);
      // Flip claimable state to true
      LAND.flipClaimableState();
    }

    // Setup before land balance
    uint256 landBalanceBefore = LAND.balanceOf(address(this));

    // Setup flashloan params
    uint256[] memory _ids = new uint256[](1);
    uint256[] memory _amounts = new uint256[](1);
    _ids[0] = 731;
    _amounts[0] = 1;

    // Execute flashloan
    BAYC20.flashLoan(_ids, _amounts, address(FLASHSIDE), "");

    // Withdraw land tokens
    FLASHSIDE.withdrawLand(_ids);

    // Setup after land balance
    uint256 landBalanceAfter = LAND.balanceOf(address(this));

    // Check for balance increment
    assertEq(landBalanceBefore + 1, landBalanceAfter);
  }

  /// @notice Test claiming land when claimable is toggled false
  function testClaimLandNotClaimable() public {
    // Get claimable status
    bool isClaimable = LAND.claimableActive();
    // Toggle claimable to false
    if (isClaimable) {
      // Get contract operator
      address landOperator = LAND.operator();
      // Mock operator for next call
      VM.prank(landOperator);
      // Flip claimable state to false
      LAND.flipClaimableState();
    }

    // Setup flashloan params
    uint256[] memory _ids = new uint256[](1);
    uint256[] memory _amounts = new uint256[](1);
    _ids[0] = 731;
    _amounts[0] = 1;

    // Setup expected revert
    VM.expectRevert("Land claim not active");
    // Execute flashloan
    BAYC20.flashLoan(_ids, _amounts, address(FLASHSIDE), "");
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
