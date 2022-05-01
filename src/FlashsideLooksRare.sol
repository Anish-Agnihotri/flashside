// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// ============ Libraries ============

// These definitions are taken from across multiple dydx contracts, and are
// limited to just the bare minimum necessary to make flash loans work.
// Source: https://gist.github.com/cryptoscopia/1156a368c19a82be2d083e04376d261e
library Types {
  enum AssetDenomination { Wei, Par }
  enum AssetReference { Delta, Target }
  struct AssetAmount {
    bool sign;
    AssetDenomination denomination;
    AssetReference ref;
    uint256 value;
  }
}

library Account {
  struct Info {
    address owner;
    uint256 number;
  }
}

library Actions {
  enum ActionType {
    Deposit, Withdraw, Transfer, Buy, Sell, Trade, Liquidate, Vaporize, Call
  }
  struct ActionArgs {
    ActionType actionType;
    uint256 accountId;
    Types.AssetAmount amount;
    uint256 primaryMarketId;
    uint256 secondaryMarketId;
    address otherAddress;
    uint256 otherAccountId;
    bytes data;
  }
}

// LooksRare order types
library OrderTypes {
  struct MakerOrder {
    bool isOrderAsk; // true --> ask / false --> bid
    address signer; // signer of the maker order
    address collection; // collection address
    uint256 price; // price (used as )
    uint256 tokenId; // id of the token
    uint256 amount; // amount of tokens to sell/purchase (must be 1 for ERC721, 1+ for ERC1155)
    address strategy; // strategy for trade execution (e.g., DutchAuction, StandardSaleForFixedPrice)
    address currency; // currency (e.g., WETH)
    uint256 nonce; // order nonce (must be unique unless new maker order is meant to override existing one e.g., lower ask price)
    uint256 startTime; // startTime in timestamp
    uint256 endTime; // endTime in timestamp
    uint256 minPercentageToAsk; // slippage protection (9000 --> 90% of the final price must return to ask)
    bytes params; // additional parameters
    uint8 v; // v: parameter (27 or 28)
    bytes32 r; // r: parameter
    bytes32 s; // s: parameter
  }

  struct TakerOrder {
    bool isOrderAsk; // true --> ask / false --> bid
    address taker; // msg.sender
    uint256 price; // final price for the purchase
    uint256 tokenId;
    uint256 minPercentageToAsk; // // slippage protection (9000 --> 90% of the final price must return to ask)
    bytes params; // other params (e.g., tokenId)
  }
}

/// ============ Interfaces ============

// dYdX Solo Margin
interface ISoloMargin {
  /// @notice Flashloan operate from dYdX
  function operate(Account.Info[] memory accounts, Actions.ActionArgs[] memory actions) external;
}

// Wrapped Ether
interface IWETH {
  /// @notice Deposit ETH to WETH
  function deposit() external payable;
  /// @notice WETH balance
  function balanceOf(address holder) external returns (uint256);
  /// @notice ERC20 Spend approval
  function approve(address spender, uint256 amount) external returns (bool);
  /// @notice ERC20 transferFrom
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// ERC721
interface IERC721 {
  /// @notice Approve spend for all
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

// LooksRare exchange
interface ILooksRareExchange {
  /// @notice Match a taker ask with maker bid
  function matchBidWithTakerAsk(
    OrderTypes.TakerOrder calldata takerAsk,
    OrderTypes.MakerOrder calldata makerBid
  ) external;
  /// @notice Match ask with ETH/WETH bid
  function matchAskWithTakerBidUsingETHAndWETH(
    OrderTypes.TakerOrder calldata takerBid,
    OrderTypes.MakerOrder calldata makerAsk
  ) external payable;
}

/// @title FlashsideLooksRare
/// @author Anish Agnihotri
/// @notice Buy MAYC from LooksRare via dYdX flashloan, claims land, and sells MAYC into collection floor
contract FlashsideLooksRare {
  // ============ Immutable storage ============

  /// @dev Wrapped Ether contract
  IWETH internal immutable WETH;
  /// @dev Contract owner
  address internal immutable OWNER;
  /// @dev Otherside land contract
  OthersideLand internal immutable LAND;
  /// @dev dYdX Solo Margin contract
  ISoloMargin internal immutable SOLO_MARGIN;
  /// @dev LooksRare exchange contract
  ILooksRareExchange internal immutable LOOKSRARE;

  // ============ Constructor ============

  constructor(
    address _WETH,
    address _LAND,
    address _MAYC,
    address _MAYC_TRANSFER_MANAGER,
    address _LOOKSRARE,
    address _SOLO_MARGIN
  ) {
    // Setup contract owner
    OWNER = msg.sender;
    // Setup Wrapped Ether contract
    WETH = IWETH(_WETH);
    // Setup Otherside land contract
    LAND = OthersideLand(_LAND);
    // Setup dYdX Solo Margin contract
    SOLO_MARGIN = ISoloMargin(_SOLO_MARGIN);
    // Setup LooksRare exchange contract
    LOOKSRARE = ILooksRareExchange(_LOOKSRARE);

    // Setup max approval amount
    uint256 maxApproval = 2**256 - 1;
    // Give dYdX Solo Margin infinite approval to pull wETH post flashloan
    WETH.approve(_SOLO_MARGIN, maxApproval);
    // Give LooksRare exchange infinite approval to spend wETH
    WETH.approve(_LOOKSRARE, maxApproval);

    // Give LooksRare exchange approval to spend all MAYC
    IERC721(_MAYC).setApprovalForAll(_MAYC_TRANSFER_MANAGER, true);
  }

  /// @notice Initiates flashloan from dYdX (execution in callFunction callback)
  /// @param purchaseOrder to match against and buy MAYC
  /// @param saleOrder to match against to sell MAYC
  function initiateFlashloan(
    OrderTypes.MakerOrder calldata purchaseOrder,
    OrderTypes.MakerOrder calldata saleOrder
  ) external {
    // Check if land claim is claimable
    bool landClaimActive = LAND.claimableActive();
    // If claim not active, revert
    if (!landClaimActive) revert("Land claim not active");

    // Setup dYdX flash loan
    Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);
    operations[0] = Actions.ActionArgs({
      // Withdraw wETH from dYdX
      actionType: Actions.ActionType.Withdraw,
      accountId: 0,
      amount: Types.AssetAmount({
        sign: false,
        denomination: Types.AssetDenomination.Wei,
        ref: Types.AssetReference.Delta,
        // Of purchase debit amount
        value: purchaseOrder.price
      }),
      // Wrapped Ether
      primaryMarketId: 0,
      secondaryMarketId: 0,
      otherAddress: address(this),
      otherAccountId: 0,
      data: ""
    });
    operations[1] = Actions.ActionArgs({
      // Execute call function
      actionType: Actions.ActionType.Call,
      accountId: 0,
      amount: Types.AssetAmount({
        sign: false,
        denomination: Types.AssetDenomination.Wei,
        ref: Types.AssetReference.Delta,
        value: 0
      }),
      primaryMarketId: 0,
      secondaryMarketId: 0,
      otherAddress: address(this),
      otherAccountId: 0,
      // Purchase order
      data: abi.encode(purchaseOrder, saleOrder)
    });
    operations[2] = Actions.ActionArgs({
      // Deposit Wrapped Ether back to dYdX
      actionType: Actions.ActionType.Deposit,
      accountId: 0,
      amount: Types.AssetAmount({
        sign: true,
        denomination: Types.AssetDenomination.Wei,
        ref: Types.AssetReference.Delta,
        // Loan amount + 2 wei fee
        value: purchaseOrder.price + 2 wei
      }),
      // Wrapped Ether
      primaryMarketId: 0,
      secondaryMarketId: 0,
      otherAddress: address(this),
      otherAccountId: 0,
      data: ""
    });
    Account.Info[] memory accountInfos = new Account.Info[](1);
    accountInfos[0] = Account.Info({owner: address(this), number: 1});

    // Execute flash loan
    SOLO_MARGIN.operate(accountInfos, operations);
  }

  function callFunction(
    address sender,
    Account.Info memory accountInfo,
    bytes memory data
  ) external {
    // Decode variables passed in data
    (
      OrderTypes.MakerOrder memory purchaseAsk,
      OrderTypes.MakerOrder memory saleBid
    ) = abi.decode(data, (OrderTypes.MakerOrder, OrderTypes.MakerOrder));

    // Setup our taker bid to buy
    OrderTypes.TakerOrder memory purchaseBid = OrderTypes.TakerOrder({
      isOrderAsk: false,
      taker: address(this),
      price: purchaseAsk.price,
      tokenId: purchaseAsk.tokenId,
      minPercentageToAsk: purchaseAsk.minPercentageToAsk,
      params: ""
    });

    // Accept maker ask order and purchase MAYC
    LOOKSRARE.matchAskWithTakerBidUsingETHAndWETH(
      purchaseBid,
      purchaseAsk
    );

    // Setup BAYC claim array
    uint256[] memory alpha;
    // Setup MAYC claim array with purchased tokenId
    uint256[] memory beta = new uint256[](1);
    beta[0] = purchaseAsk.tokenId;

    // Claim land from BAYC
    LAND.nftOwnerClaimLand(alpha, beta);

    // Setup our taker bid to sell
    OrderTypes.TakerOrder memory saleAsk = OrderTypes.TakerOrder({
      isOrderAsk: true,
      taker: address(this),
      price: saleBid.price,
      tokenId: purchaseAsk.tokenId,
      minPercentageToAsk: saleBid.minPercentageToAsk,
      params: ""
    });

    // Accept maker ask order and sell MAYC
    LOOKSRARE.matchBidWithTakerAsk(saleAsk, saleBid);

    // Convert remaining ETH balance to pay flashloan
    WETH.deposit{value: address(this).balance}();
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

  /// @notice Withdraws contract ETH balance to owner address
  function withdrawBalance() external {
    (bool sent, ) = OWNER.call{value: address(this).balance}("");
    if (!sent) revert("Could not withdraw balance");
  }

  /// @notice Withdraw contract WETH balance to owner address
  function withdrawBalanceWETH() external {
    WETH.transferFrom(address(this), OWNER, WETH.balanceOf(address(this)));
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

  /// @notice Allows receiving ETH
  receive() external payable {}
}