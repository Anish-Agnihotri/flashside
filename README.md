# Flashside

Flashside is a set of NFT MEV contracts to claim [Otherside land NFTs](https://twitter.com/yugalabs/status/1505014986556551172) from various [BAYC](https://opensea.io/collection/boredapeyachtclub) and [MAYC](https://opensea.io/collection/mutant-ape-yacht-club) pools, via flashloans or flashswaps.

Assuming land has a floor of at least 2.5 ETH (the pre-sale whitelist cost) and hypothetically 5+ ETH, only profitable opportunities are mocked. For this reason, strategies like flashloaning xBAYC from NFTX are ignored (because of their relatively high average cost of 20 ETH/land).

## Potential strategies

1. Flashloans from NFT pools like [NFTX](https://nftx.org/)/[NFT20](https://nft20.io/). Only profitable for some pairs due to high index token costs (for example, NFTX costs `0.14x` token: `0.04` on claim, `0.1` on deposit)
2. Atomic purchase, claim, and sale into collection floors via [LooksRare](https://looksrare.org/)

## Implemented Strategies

1. `FlashsideNFT20` — 0-cost flashloan and claim via BAYC from NFT20
2. `FlashsideLooksRare` — ~1-1.5 ETH/land atomic purchase, claim, and sale via MAYC from LooksRare

## Test

Tests use [Foundry: Forge](https://github.com/gakonst/foundry).

Install Foundry using the installation steps in the README of the linked repo.

```bash
# Get dependencies
forge update

# Run tests against mainnet fork
forge test --fork-url=YOUR_MAINNET_RPC_URL
```

## Credits

- [@sinasab](https://github.com/sinasab) for alerting me of opportunity + nerd-sniping.
- [/u/cryptoscopia](https://github.com/cryptoscopia) for [dydxFlashLoanTemplate.sol](https://gist.github.com/cryptoscopia/1156a368c19a82be2d083e04376d261e).

## Disclaimer

These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. Anish Agnihotri is not liable for any of the foregoing. Users should proceed with caution and use at their own risk.
