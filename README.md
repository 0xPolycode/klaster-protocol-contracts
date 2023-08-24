# Thalamus Protocol

<img style="height:100px" src="https://github.com/0xPolycode/thalamus-protocol-tech/assets/129866940/c0b2427d-e853-40b6-847f-2328f7c47c7d"></img>

## Introduction

Here, we propose how [Chainlink's CCIP technology](https://docs.chain.link/ccip) can be used to create native multichain tokens. By native, we mean the token implicitly having the ability to hop from one chain to another.

This potentially unlocks many interesting use cases - not limited to bridge only. One of them being the ability to interact with all of DeFi
on different chains while only transacting and calling the standardized functions on the token itself on one single chain.
This way we:
1. hide the complexity of the infrastructure from the user - he doesn't need to know all the specifics of what
infrastructure/chain is the app he's interacting with running on
2. make user's life easier by allowing him to execute cross chain DeFi actions while paying for the gas with only one token on their native chain

Our ThalamusERC20 implementation unlocks these use cases and all the heavy load is being executed by the Chainlink's CCIP messaging protocol.

## Smart Contracts

1. **[ThalamusERC20.sol](./src/assets/ThalamusERC20.sol)** - ERC20 standard implementation extended with the `rtc(...)` function. Using this function, token holders can hop from one chain to another and execute any transaction on the destination chain, with the bridged tokens supplied during the execution. Best of all, there's no need for DeFi protocols to adapt. We only need to have the adapter contracts deployed for any protocol we want to support as a multichain protcool and everything else works out of the box (see our example for UniV2Adapter).


2. **[UniV2RouterAdapter.sol](./src/adapters/UniV2RouterAdapter.sol)** - An example implementation showing how easy it is to build the adapter contract for any existing protcol. This adapter knows how to swap tokens on UniV2 and then bridge the resulting token back to the chain from which the owner has requested the remote swap action. For the time being, we only deployed this adapter on [Sepolia network](https://sepolia.etherscan.io/address/0x101Cd6a6E9B436eB3c14E8454bc17d15fF6D6239).
We executed one remote swap transaction to test this out, by swapping 1.0 TokenA for TokenB.
The transaction was executed on the Avax Fuji Testnet which:
    1) bridged 1.0 TokenA to Sepolia using CCIP
    2) swapped 1.0 TokenA for TokenB using the Thalamus UniV2RouterAdapter
    3) bridged back the resulting TokenB amount to Avax Fuji Testnet chain

    The full cross chain swap process we executed can be [examined here](https://ccip.chain.link/tx/0x99882733405dee2411d050205850b5254c163c90ba97bf0df56ffc0f3cecc3d9).

3. **[ThalamusGovernor.sol](./src/ThalamusGovernor.sol)** - Singleton used to create new ThalamusERC20 instances. It's leveraging the powers `CREATE2` opcode and allows for deploying a truly native multichain ERC20 token (ThalamusERC20) on multiple different chains in one single on-chain transaction! All the deployments on different chains will be living at the same blockchain address, which makes things easier and gives the token its global identity detached from the actual blockchain network.

## Optimistic Remote Transaction Call & Cross-Chain DeFi (Work in Progress)

The next step in the development of Thalamus Protcol is the addition of 'Optimistic Remote Transaction Calls' (in the following text - ORTCs). This feature
allows users to have all of their assets on their favorite blockchain network and interact with dApps on *all* blockchain networks without bridging
their assets. 

So for example, a user who has all of their tokens on Polygon, could easily interact with Uniswap or AAVE on Optimism or Avalanche, without ever buying the network native tokens for Optimism or Avalanche *and* without setting any new RPCs in their wallet settings. They would simply sign a transaction and send it to Polygon. CCIP would handle the rest!

### How does it work?

ORTC works through functions exposed on the multichain token itself. The process is the following:

1. The user calls the `ortc` function on the multichain token. The function takes the following parameters:
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
2. The ORTC function will optimistically 'burn' the 'Tokens Used' amount of ThalamusERC20 on the source chain. This means that these tokens will not be available for usage on the source chain. After this, the ORTC function will call CCIP with the query parameters and the proof of tokens burned on the source chain. Each CCIP call will also have an `expiry` period, which means that the request cannot be executed on the destination chain if the CCIP request arrived late (for any possible reason).

3. The ThalamusERC20 contract will receive the message, mint the equivalent amount of the ThalamusERC20 that was burned on the source chain and then call the function which the message defines. The protocol which called the function is then able to use that minted token to swap, stake, lend or perform any other action on the ThalamusERC20 token.

    When this action is completed, the destination chain ThalamusERC20 can either remain on the destination chain (in the case of locking, staking, ...) *or* it or another token can be bridged back to the source chain for safekeeping. 

    For example, if the action would be a remote transcation call to open a Uniswap LP position, the LP tokens would be wrapped into Multichain LP tokens and transferred backed through CCIP to the source chain. Or if the user would e.g. supply Dai to AAVE, the aDAI token would be wrapped into it's multichain representation and bridged back to the source chain.

    This implementation makes multichain tokens fully compatible with all DeFi protocols by simply writing small 'wrapper' contracts which handle the functionality of wrapping the received tokens and bridging them back to the source chain.

    We already implemented the Uniswap Router adapter to demonstrate this functionality (see above).

4. Handshake - the source chain ThalamusERC20 contract is waiting for the response from the destination chain that the transaction was successfull. If you recall the `expiry` variable from the 2nd step - this is where it comes into play. The source chain has _optimistically_ assumed that the transcation will be a success. If, however, it does not receive the handshake success from CCIP in some defined amount of time - e.g. `3 * expiry`, it will consider the destination chain action a failure - and provide the user with steps to recover their funds - usually by allowing them to mint their tokens back.

### Allow & Execute

Since the recipient of the CCIP call on the destination chain is the token contract itself, it can (in a single transaction), create an allowance to a different smart contract, execute the required function and (if needed) revoke the allowance.

This is required behavior for the AAVE/Uniswap case presented above and another feature which makes MultiChain Tokens an amazing solution for cross-chain DeFi!

## Deployments

Official ThalamusGovernor instances are deployed at address

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
