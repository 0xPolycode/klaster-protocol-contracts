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

## Optimistic Remote Transaction Call & Cross-Chain DeFi (Work in Progress)

The next step in the development of McTokens is the addition of 'Optimistic Remote Transaction Calls' (in the following text - ORTCs). This feature
allows users to have all of their assets on their favorite blockchain network and interact with dApps on *all* blockchain networks without bridging
their assets. 

So for example, a user who has all of their tokens on Polygon, could easily interact with Uniswap or AAVE on Optimism or Avalanche, without ever buying the network native tokens for Optimism or Avalanche *and* without setting any new RPCs in their wallet settings. They would simply sign a transaction and send it to Polygon. CCIP would handle the rest!

### How does it work?

OTRC works through functions exposed on the multichain token itself. The process is the following:

1. The user calls the `otrc` function on the multichain token. The function takes the following parameters:
    * Destination Chain - Chain ID of the destination chain on which the function will be executed
    * Contract Address - The address of the contract on the destination chain, on which the function will be executed
    * Function name - The name of the function on which the contract will be executed
    * Function params - The list of parameters for the function which will be executed
    * Tokens used amount - The amount of tokens that will be delegated to the destination chain for usage in the app
    * Signed Hash - The hash of the 

   An example function call would look something like this:
   ```
    ChainID: 10 (Optimism)
    Contract address: 0xABC...DEF
    Function Name: deposit
    Function Params: [1000000000]
    Tokens Used: 1000000000
   ```
2. The OTRC function will optimistically 'burn' the 'Tokens Used' amount of McToken on the source chain. This means that these tokens will not be available for usage on the source chain. After this, the OTRC function will call CCIP with the query parameters and the proof of tokens burned on the source chain. Each CCIP call will also have an `expiry` period, which means that the request cannot be executed on the destination chain if the CCIP request arrived late (for any possible reason).

3. The McToken contract will receive the message, mint the equivalent amount of the McToken that was burned on the source chain and then call the function which the message defines. The protocol which called the function is then able to use that minted token to swap, stake, lend or perform any other action on the McToken token.

    When this action is completed, the destination chain McToken can either remain on the destination chain (in the case of locking, staking, ...) *or* it or another token can be bridged back to the source chain for safekeeping. 

    For example, if the action would be a remote transcation call to open a Uniswap LP position, the LP tokens would be wrapped into Multichain LP tokens and transferred backed through CCIP to the source chain. Or if the user would e.g. supply Dai to AAVE, the aDAI token would be wrapped into it's multichain representation and bridged back to the source chain.

    This implementation makes multichain tokens fully compatible with all DeFi protocols by simply writing small 'wrapper' contracts which handle the functionality of wrapping the received tokens and bridging them back to the source chain.

    We plan on building wrappers around AAVE and Uniswap to demonstrate this functionality.

4. Handshake - the source chain McToken contract is waiting for the response from the destination chain that the transaction was successfull. If you recall the `expiry` variable from the 2nd step - this is where it comes into play. The source chain has _optimistically_ assumed that the transcation will be a success. If, however, it does not receive the handshake success from CCIP in some defined amount of time - e.g. `3 * expiry`, it will consider the destination chain action a failure - and provide the user with steps to recover their funds - usually by allowing them to mint their tokens back. 

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
