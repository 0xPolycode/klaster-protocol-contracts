# Multichain Token

## Introduction

Here, we propose how [Chainlink's CCIP technology](https://docs.chain.link/ccip) can be used to create native multichain tokens.
By native, we mean the token implicitly having the ability to hop from one chain to another.

This potentially unlocks many other interesting use cases - not limited to bridge only. One of them being the ability to interact with all of DeFi
on different chains while only transacting and calling the standardized functions on the token itself on one single chain.
This way we:
1. hide the complexity of the infrastructure from the user - he doesn't need to know all the specifics of what
infrastructure/chain is the app he's interacting with running on
2. make user's life easier by allowing him to execute cross chain DeFi actions while paying for the gas with only one token on their native chain

Our McToken implementation unlocks these use cases and all the heavy load is being executed by the Chainlink's CCIP messaging protocol.

## Smart Contracts

You will find two smart contracts in this repo:
1. **[McToken.sol](./src/McToken.sol)** - ERC20 standard implementation extended with the `bridge(uint256 chainId, uint256 amount)` function. Token holders can hop from one chain to another by calling this function directly on the token implementation.
2. **[McTokenFactory.sol](./src/McTokenFactory.sol)** - Singleton used to create new McToken instances. It's leveraging the powers `CREATE2` opcode and allows for deploying a truly native multichain ERC20 token (McToken) on multiple different chains in one single on-chain transaction! All the deployments on different chains will be living at the same blockchain address, which makes things easier and gives the token its global identity detached from the actual blockchain network.

## Deployments

Official McTokenFactory instances are deployed at address

`0x17009c59ab334a8b997edf620f6ed1a0cfb6c2d7`

on following blockchain networks (TESTNET only):

- [SEPOLIA](https://sepolia.etherscan.io/address/0x17009c59ab334a8b997edf620f6ed1a0cfb6c2d7)
- [ARBITRUM GÖRLI](https://testnet.arbiscan.io/address/0x17009c59ab334a8b997edf620f6ed1a0cfb6c2d7)
- [OPTIMISM GÖRLI](https://goerli-optimism.etherscan.io/address/0x17009c59ab334a8b997edf620f6ed1a0cfb6c2d7)
- [POLYGON MUMBAI](https://mumbai.polygonscan.com/address/0x17009c59ab334a8b997edf620f6ed1a0cfb6c2d7)

## Live Demo

https://polycode-ccip-multichain-token-frontend.vercel.app/

## Roadmap

[✅] PoC Smart Contracts implementation. 

*Create multichain native tokens and support the bridging between chains.*

[✅] PoC Frontend.

*Launch the basic frontend implementation allowing others to play around, deploy tokens on testnets and monitor the operations' status on the [CCIP explorer](https://ccip.chain.link/).*

[...] Add support for *wrap()* function.

*This way we not only allow for creating new multichain tokens but also wrapping existing ERC20 tokens into their multichain counterpart and, by doing so, unlocking all the same possibilities as if the token was deployed as the native multichain token.*

[...] Define & implement cross-chain execution standard

*Implement the support for executing cross-chain transactions natively on the multichain token by using the CCIP messaging protocol and, in turn, allowing users to execute any token operation on any chain by only transacting and spending gas on their source chain.*
