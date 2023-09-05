// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";

import {CCIPLaneProvider} from "./CCIPLaneProvider.sol";
import {IERC20Metadata, KlasterERC20} from "./assets/KlasterERC20.sol";

interface IKlasterGovernor {
    
    struct TokenWithBalance {
        address tokenAddress;
        string name;
        string symbol;
        uint8 decimals;
        uint256 balance;
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

contract KlasterGovernor is CCIPLaneProvider, IKlasterGovernor, CCIPReceiver, OwnerIsCreator {

    mapping (address => bool) deployedTokens;
    address[] deployedTokensList;

    mapping (address => address) wrappedTokens; // token => wrapped token
    mapping (address => mapping (address => uint256)) wrappedAmounts; // wrapped token => account => wrapped amount

    bytes private _klasterErc20Impl;

    constructor() CCIPReceiver(_getRouterAddy(block.chainid)) {
        _klasterErc20Impl = type(KlasterERC20).creationCode;
    }
    
    function upgradeErc20Impl(bytes memory bytecode) external onlyOwner {
        _klasterErc20Impl = bytecode;
    }

    function registerAdapter(address payable token, address targetContract, address adapter) external onlyOwner {
        KlasterERC20(token).registerAdapter(targetContract, adapter);
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
        
        bytes memory bytecode = abi.encodePacked(_klasterErc20Impl, abi.encode(name, symbol));
        bytes32 calculatedSalt = keccak256(abi.encodePacked(msg.sender, salt));
        address payable token;
        assembly {
            token := create2(0, add(bytecode, 32), mload(bytecode), calculatedSalt)
        }
        KlasterERC20(token).mint(msg.sender, initialSupply);
        deployedTokens[token] = true;
        deployedTokensList.push(token);
        return token;
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

    // get the ByteCode of the contract KlasterERC20
    function getBytecode(string memory name, string memory symbol) private pure returns (bytes memory) {
        bytes memory bytecode = type(KlasterERC20).creationCode;
        return abi.encodePacked(bytecode, abi.encode(name, symbol));
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

        require(
            abi.decode(any2EvmMessage.sender, (address)) == address(this),
            "Only the official deployer can deploy KlasterERC20 token."
        );

        (
            address caller,
            string memory name,
            string memory symbol,
            bytes32 salt,
            uint256 initialSupply
        ) = abi.decode(any2EvmMessage.data, (address, string, string, bytes32, uint256));

        KlasterERC20 token = new KlasterERC20{salt: salt}(name, symbol);
        token.mint(caller, initialSupply);
    }


    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

}
