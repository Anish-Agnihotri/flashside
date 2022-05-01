// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// ============ Imports ============

import "forge-std/Vm.sol"; // Vm
import "forge-std/Test.sol"; // Forge test
import "../src/FlashsideLooksRare.sol"; // FlashsideLooksRare

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

/// @title FlashsideLooksRareTest
/// @author Anish Agnihotri
/// @notice Test FlashsideLooksRare
contract FlashsideLooksRareTest is Test {
  // ============  Storage ============

  /// @notice Cheatcodes
  Vm public VM;
  /// @notice Wrapped Ether contract
  IWETH public WETH;
  /// @notice Land contract
  OthersideLandExtended public LAND;
  /// @notice FlashsideLooksRare contract
  FlashsideLooksRare public FLASHSIDE;

  // ============  Functions ============

  /// @notice Setup tests
  function setUp() public {
    // Setup cheatcodes
    VM = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    // Setup WETH
    WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // Setup Otherside land contract
    LAND = OthersideLandExtended(0x34d85c9CDeB23FA97cb08333b511ac86E1C4E258);
    // Initialize FlashsideLooksRare
    FLASHSIDE = new FlashsideLooksRare(
      address(WETH), // Wrapped Ether
      address(LAND), // Otherside land
      0x60E4d786628Fea6478F785A6d7e704777c86a7c6, // MAYC
      0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e, // MAYC transfer manager
      0x59728544B08AB483533076417FbBB2fD0B17CE3a, // LooksRare exchange
      0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e // dYdX Solo Margin
    );
  }

  /// @notice Test claiming excess ETH
  function testClaimExcessETH() public {
    // Enforce flashside contract starts with 0 balance
    VM.deal(address(FLASHSIDE), 0);

    // Collect balance before
    uint256 balanceBefore = address(this).balance;

    // Send 5 ETH to contract
    payable(FLASHSIDE).transfer(5 ether);

    // Assert balance now 5 less
    assertEq(address(this).balance, balanceBefore - 5 ether);

    // Withdraw 5 ETH
    FLASHSIDE.withdrawBalance();

    // Collect balance after
    uint256 balanceAfter = address(this).balance;

    // Assert balance matches
    assertEq(balanceAfter, balanceBefore);
  }

  /// @notice Test claiming excess WETH
  function testClaimExcessWETH() public {
    // Deposit 5 ETH to WETH
    WETH.deposit{value: 5 ether}();

    // Collect balance before
    uint256 balanceBefore = WETH.balanceOf(address(this));

    // Send 5 WETH to contract
    WETH.transferFrom(address(this), address(FLASHSIDE), 5 ether);

    // Assert balance now 0
    assertEq(WETH.balanceOf(address(this)), 0);

    // Withdraw 5 WETH
    FLASHSIDE.withdrawBalanceWETH();

    // Collect balance after
    uint256 balanceAfter = WETH.balanceOf(address(this));

    // Assert balance matches
    assertEq(balanceBefore, balanceAfter);
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

    // Enforce flashside contract starts with 0 balance
    VM.deal(address(FLASHSIDE), 0);

    // Setup purchase order
    // Details from LooksRare API (https://looksrare.github.io/api-docs/#/Orders/OrderController.getOrders)
    OrderTypes.MakerOrder memory purchaseOrder = OrderTypes.MakerOrder({
      isOrderAsk: true,
      signer: 0x20C3cc9E8869ADc1B7efAd187f10969A449653F5,
      collection: 0x60E4d786628Fea6478F785A6d7e704777c86a7c6,
      price: 44900000000000000000,
      tokenId: 24136,
      amount: 1,
      strategy: 0x56244Bb70CbD3EA9Dc8007399F61dFC065190031,
      currency: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      nonce: 144,
      startTime: 1651219901,
      endTime: 1653811870,
      minPercentageToAsk: 8500,
      params: "",
      v: 28,
      r: 0x98e8f39977eed65a7420fdaf6fd8a244ce9f0f8b037d3f34c1ea652c0e5e9d71,
      s: 0x1257c9558d7099ad5681643d100db5a1ccda47dbaa5dd28125f556933f071313
    });

    // Setup sale order
    // Details from LooksRare API (https://looksrare.github.io/api-docs/#/Orders/OrderController.getOrders)
    OrderTypes.MakerOrder memory sellOrder = OrderTypes.MakerOrder({
      isOrderAsk: false,
      signer: 0x9A968a4E20612cD26f09246358316eFfc19219E5,
      collection: 0x60E4d786628Fea6478F785A6d7e704777c86a7c6,
      price: 31990000000000000000,
      tokenId: 0,
      amount: 1,
      strategy: 0x86F909F70813CdB1Bc733f4D97Dc6b03B8e7E8F3,
      currency: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      nonce: 8,
      startTime: 1651358759,
      endTime: 1651445153,
      minPercentageToAsk: 8500,
      params: "",
      v: 28,
      r: 0x71104a9867777d84929c1565b8b280775bc35a76339d2908227799f1752635fc,
      s: 0x3eeb1e56af51e5ed3491ff082ad90ac1b8fd95e2d0879930354fa11e57144efc
    });

    // Setup before land balance
    uint256 landBalanceBefore = LAND.balanceOf(address(FLASHSIDE));

    // Calculate proceeds from sale (-4.5% fees)
    uint256 saleProceeds = sellOrder.price - ((sellOrder.price * 45) / 1000);
    // Calculate difference between orders (cost/land)
    uint256 landCost = purchaseOrder.price - saleProceeds;
    // Transfer difference + 2 wei to contract
    payable(address(FLASHSIDE)).transfer(landCost + 2 wei);

    // Execute flash loan
    FLASHSIDE.initiateFlashloan(purchaseOrder, sellOrder);

    // Setup after land balance
    uint256 landBalanceAfter = LAND.balanceOf(address(FLASHSIDE));

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

    // Setup purchase order
    // Details from LooksRare API (https://looksrare.github.io/api-docs/#/Orders/OrderController.getOrders)
    OrderTypes.MakerOrder memory purchaseOrder = OrderTypes.MakerOrder({
      isOrderAsk: true,
      signer: 0x20C3cc9E8869ADc1B7efAd187f10969A449653F5,
      collection: 0x60E4d786628Fea6478F785A6d7e704777c86a7c6,
      price: 44900000000000000000,
      tokenId: 24136,
      amount: 1,
      strategy: 0x56244Bb70CbD3EA9Dc8007399F61dFC065190031,
      currency: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      nonce: 144,
      startTime: 1651219901,
      endTime: 1653811870,
      minPercentageToAsk: 8500,
      params: "",
      v: 28,
      r: 0x98e8f39977eed65a7420fdaf6fd8a244ce9f0f8b037d3f34c1ea652c0e5e9d71,
      s: 0x1257c9558d7099ad5681643d100db5a1ccda47dbaa5dd28125f556933f071313
    });

    // Setup sale order
    // Details from LooksRare API (https://looksrare.github.io/api-docs/#/Orders/OrderController.getOrders)
    OrderTypes.MakerOrder memory sellOrder = OrderTypes.MakerOrder({
      isOrderAsk: false,
      signer: 0x9A968a4E20612cD26f09246358316eFfc19219E5,
      collection: 0x60E4d786628Fea6478F785A6d7e704777c86a7c6,
      price: 31990000000000000000,
      tokenId: 0,
      amount: 1,
      strategy: 0x86F909F70813CdB1Bc733f4D97Dc6b03B8e7E8F3,
      currency: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      nonce: 8,
      startTime: 1651358759,
      endTime: 1651445153,
      minPercentageToAsk: 8500,
      params: "",
      v: 28,
      r: 0x71104a9867777d84929c1565b8b280775bc35a76339d2908227799f1752635fc,
      s: 0x3eeb1e56af51e5ed3491ff082ad90ac1b8fd95e2d0879930354fa11e57144efc
    });

    // Setup expected revert
    VM.expectRevert("Land claim not active");
    // Execute flash loan
    FLASHSIDE.initiateFlashloan(purchaseOrder, sellOrder);
  }

  /// @notice Allows receiving ETH
  receive() external payable {}
}