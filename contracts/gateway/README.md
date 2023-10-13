# Klaster Gateway

Here we introduce an interesting concept, and a product called **Klaster Gateway**.
We use solidity magic on top of [Chainlink CCIP](https://docs.chain.link/ccip) to convert **ANY** blockchain adress into a cross-chain wallet.

The multichain address derived from your master wallet can be used to:
 - deploy contracts
 - deploy contracts using create2 opcode
 - recieve & transfer assets on multiple chains
 - batch multiple transactions into one single call (transactions don't have to be targeting the same chain)
 - execute any arbitrary call on any contract & any supported chain (DeFi)

Basically, it's a full featured wallet derived from your base wallet. The best part here is, your multichain derived wallet already exists and can be precomputed. You don't need to execute any action to activate or "create" this wallet. You can literally start using it right now.

## Use cases

### EOA Integration

Converts your MetaMask or any other wallet into a multichain wallet. This means one can start interacting with other chains, and receive/send assets there, by only signing transactions on one "home chain". Sign on one chain with one gas token, and execute actions on any other chain.

### Smart Contract Integration

Yes, a smart contract too can have it's multichain address.

Wether you are a:
 - DAO
 - Governance Contract
 - Gnosis Safe Multisig
 - really any Smart Contract Wallet,

you were historically bound to one chain. The one where your contract is deployed at. And all you could "see" and interact with, was contained within this one blockchain network.

But if you use Klaster Gateway and derive the address from your multisig, DAO or any other contract wallet, you're instantly connected to multiple chains at the same time.

You can start signing transactions right away, and by interacting with our trusted & immutable Klaster Gateway you can manage your derived multichain address easily. Multisig can start receiving assets on other chains, DAOs can execute proposals to execute a cross-chain action and so on.

## Deployments

Deployment addresses.

## Documentation

To read more about how the Gateway works and how to start using it read our extensive docs [here](TODO).
