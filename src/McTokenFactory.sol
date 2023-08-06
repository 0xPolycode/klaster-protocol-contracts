// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20Metadata, McToken} from "./McToken.sol";

interface ICCIPBridgeableDeployer {
    
    struct TokenWithBalance {
        address tokenAddress;
        string name;
        string symbol;
        uint8 decimals;
        uint256 balance;
    }

    struct ChainConfig {
        string name;
        address router;
        uint64 selector;
    }
    
    function calculateAddress(
        address caller,
        string memory name,
        string memory symbol,
        string memory salt
    ) external view returns (address);

    function getBatchDeployFee(
        address caller,
        string memory name,
        string memory symbol,
        string memory salt,
        uint256[] memory chainIds,
        uint256[] memory initialSupplies
    ) external view returns (uint256);

    function getTokens(address forWallet) external view returns (TokenWithBalance[] memory);
    
    function getSupportedChains() external view returns (ChainConfig[] memory);

    function deploy(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        string memory salt
    ) external returns (address);

    function batchDeploy(
        string memory name,
        string memory symbol,
        string memory salt,
        uint256[] memory chainIds,
        uint256[] memory initialSupplies
    ) external payable returns (address);

}

contract Deployer is ICCIPBridgeableDeployer, CCIPReceiver {

    ChainConfig[] supportedChainsList;
    mapping (uint256 => ChainConfig) supportedChains; // (chainId -> chainDef) mapping
    
    mapping (address => bool) deployedTokens;
    address[] deployedTokensList;

    mapping (address => address) wrappedTokens; // token => wrapped token
    mapping (address => mapping (address => uint256)) wrappedAmounts; // wrapped token => account => wrapped amount

    constructor() CCIPReceiver(_getRouterAddy(block.chainid)) {
        _addSupportedChains();
    }

    function batchDeploy(
        string memory name,
        string memory symbol,
        string memory salt,
        uint256[] memory chainIds,
        uint256[] memory initialSupplies
    ) external payable returns (address) {
        require(chainIds.length == initialSupplies.length, "Chain ids & initial supplies not the same length.");

        bytes32 calculatedSalt = keccak256(abi.encodePacked(msg.sender, salt));
    
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 destChainId = chainIds[i];
            uint256 initialSupply = initialSupplies[i];
            if (block.chainid == destChainId) { // if already on dest chain, deploy right away
                deploy(name, symbol, initialSupply, salt);
            } else { // else send ccip message and deploy on dest chain 
                ChainConfig memory sourceChainConfig = supportedChains[block.chainid];
                ChainConfig memory destChainConfig = supportedChains[destChainId];
                require(sourceChainConfig.router != address(0), "Source chain not supported.");
                require(destChainConfig.router != address(0), "Destination chain not supported.");

                // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
                Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                    address(this),
                    abi.encode(msg.sender, name, symbol, calculatedSalt, initialSupply),
                    address(0)
                );

                // Initialize a router client instance to interact with cross-chain router
                IRouterClient router = IRouterClient(sourceChainConfig.router);

                // Get the fee required to send the CCIP message
                uint256 fees = router.getFee(destChainConfig.selector, evm2AnyMessage);
                require(address(this).balance >= fees, "Ether amount too low. Send more ether to bridge...");

                // Send the CCIP message through the router and store the returned CCIP message ID
                router.ccipSend{value: fees}(
                    destChainConfig.selector,
                    evm2AnyMessage
                );
            }
        }

        return calculateAddress(msg.sender, name, symbol, salt);
    }

    function deploy(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        string memory salt
    ) public returns (address) {
        require(!deployedTokens[calculateAddress(msg.sender, name, symbol, salt)], "Token already deployed! Use different salt.");
        McToken token = new McToken{salt: keccak256(abi.encodePacked(msg.sender, salt))}(name, symbol);
        token.mint(msg.sender, initialSupply);
        deployedTokens[address(token)] = true;
        deployedTokensList.push(address(token));
        return address(token);
    }

    function calculateAddress(
        address caller,
        string memory name,
        string memory symbol,
        string memory salt
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), keccak256(abi.encodePacked(caller, salt)), keccak256(getBytecode(name, symbol))
            )
        );
        return address (uint160(uint(hash)));
    }

    function getBatchDeployFee(
        address caller,
        string memory name,
        string memory symbol,
        string memory salt,
        uint256[] memory chainIds,
        uint256[] memory initialSupplies
    ) external view returns (uint256) {
        require(chainIds.length == initialSupplies.length, "Chain ids & initial supplies not the same length.");
        uint256 totalFee = 0;
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 destChainId = chainIds[i];
            uint256 initialSupply = chainIds[i];
            if (block.chainid != destChainId) {
                ChainConfig memory sourceChainConfig = supportedChains[block.chainid];
                ChainConfig memory destChainConfig = supportedChains[destChainId];
                require(sourceChainConfig.router != address(0), "Source chain not supported.");
                require(destChainConfig.router != address(0), "Destination chain not supported.");

                // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
                bytes32 calculatedSalt = keccak256(abi.encodePacked(caller, salt));
                bytes memory message = abi.encode(caller, name, symbol, calculatedSalt, initialSupply);
                Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                    address(this),
                    message,
                    address(0)
                );

                // Initialize a router client instance to interact with cross-chain router
                IRouterClient router = IRouterClient(sourceChainConfig.router);

                // Get the fee required to send the CCIP message
                uint256 fees = router.getFee(destChainConfig.selector, evm2AnyMessage);
                totalFee = totalFee + fees;
            }
        }
        
        return totalFee;
    }

    function getTokens(address forWallet) external view returns (TokenWithBalance[] memory) {
        TokenWithBalance[] memory response = new TokenWithBalance[](deployedTokensList.length);
        for (uint256 i = 0; i < deployedTokensList.length; i++) {
            address tokenAddress = deployedTokensList[i];
            IERC20Metadata token = IERC20Metadata(tokenAddress);
            response[i] = TokenWithBalance(
                tokenAddress,
                token.name(),
                token.symbol(),
                token.decimals(),
                token.balanceOf(forWallet)
            );
        }
        return response;
    }

    function getSupportedChains() external view returns (ChainConfig[] memory) { return supportedChainsList; }

    // get the ByteCode of the contract ERC20Bridgeable
    function getBytecode(string memory name, string memory symbol) private pure returns (bytes memory) {
        bytes memory bytecode = type(McToken).creationCode;
        return abi.encodePacked(bytecode, abi.encode(name, symbol));
    }

    // @notice Stores CCIP chain parameters.
    // Supported chains:
    //     - ETH Mainnet
    //     - ETH Sepolia Testnet
    //     - Optimism Mainnet
    //     - Optimism Goerli Testnet
    //     - Arbitrum Goerli Testnet
    //     - Avax Mainnet
    //     - Avax Fuji Testnet
    //     - Polygon Mainnet
    //     - Polygon Mumbai Testnet
    function _addSupportedChains() internal {
        supportedChains[1] = ChainConfig("Ethereum", _getRouterAddy(1), 5009297550715157269); // eth mainnet
        supportedChainsList.push(ChainConfig("Ethereum", _getRouterAddy(1), 5009297550715157269));        
        supportedChains[10] = ChainConfig("Optimism", _getRouterAddy(10), 3734403246176062136); // optimism mainnet
        supportedChainsList.push(ChainConfig("Optimism", _getRouterAddy(10), 3734403246176062136));
        supportedChains[137] = ChainConfig("Polygon", _getRouterAddy(137), 4051577828743386545); // polygon mainnet
        supportedChainsList.push(ChainConfig("Polygon", _getRouterAddy(137), 4051577828743386545));
        supportedChains[420] = ChainConfig("Optimism Goerli Testnet", _getRouterAddy(420), 2664363617261496610); // optimism goerli testnet
        supportedChainsList.push(ChainConfig("Optimism Goerli Testnet", _getRouterAddy(420), 2664363617261496610));
        supportedChains[43113] = ChainConfig("Avax Fuji Testnet", _getRouterAddy(43113), 14767482510784806043); // avax fuji testnet
        supportedChainsList.push(ChainConfig("Avax Fuji Testnet", _getRouterAddy(43113), 14767482510784806043));
        supportedChains[43114] = ChainConfig("Avax", _getRouterAddy(43114), 6433500567565415381); // avax mainnet
        supportedChainsList.push(ChainConfig("Avax", _getRouterAddy(43114), 6433500567565415381));
        supportedChains[80001] = ChainConfig("Polygon Mumbai Testnet", _getRouterAddy(80001), 12532609583862916517); // polygon mumbai testnet
        supportedChainsList.push(ChainConfig("Polygon Mumbai Testnet", _getRouterAddy(80001), 12532609583862916517));
        supportedChains[421613] = ChainConfig("Arbitrum Goerli Testnet", _getRouterAddy(421613), 6101244977088475029); // arbitrum goerli testnet
        supportedChainsList.push(ChainConfig("Arbitrum Goerli Testnet", _getRouterAddy(421613), 6101244977088475029));
        supportedChains[11155111] = ChainConfig("Sepolia Testnet", _getRouterAddy(11155111), 16015286601757825753); // eth sepolia testnet
        supportedChainsList.push(ChainConfig("Sepolia Testnet", _getRouterAddy(11155111), 16015286601757825753));
    }

    function _getRouterAddy(uint256 chainId) internal pure returns (address router) {
        if (chainId == 1)           { router = 0xE561d5E02207fb5eB32cca20a699E0d8919a1476; }
        if (chainId == 10)          { router = 0x261c05167db67B2b619f9d312e0753f3721ad6E8; }
        if (chainId == 137)         { router = 0x3C3D92629A02a8D95D5CB9650fe49C3544f69B43; }
        if (chainId == 420)         { router = 0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26; }
        if (chainId == 43113)       { router = 0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8; }
        if (chainId == 43114)       { router = 0x27F39D0af3303703750D4001fCc1844c6491563c; }
        if (chainId == 80001)       { router = 0x70499c328e1E2a3c41108bd3730F6670a44595D1; }
        if (chainId == 421613)      { router = 0x88E492127709447A5ABEFdaB8788a15B4567589E; }
        if (chainId == 11155111)    { router = 0xD0daae2231E9CB96b94C8512223533293C3693Bf; }
    }

    // @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending arbitrary bytes cross chain.
    /// @param _receiver The address of the receiver.
    /// @param _message The bytes data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _message,
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: _message, // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 2000000, strict: false})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
        return evm2AnyMessage;
    }

    /// handle received deployment request
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {

        require(abi.decode(any2EvmMessage.sender, (address)) == address(this), "Only official deployer can deploy multi-chain token.");

        (
            address caller,
            string memory name,
            string memory symbol,
            bytes32 salt,
            uint256 initialSupply
        ) = abi.decode(any2EvmMessage.data, (address, string, string, bytes32, uint256));

        McToken token = new McToken{salt: salt}(name, symbol);
        token.mint(caller, initialSupply);
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

}
