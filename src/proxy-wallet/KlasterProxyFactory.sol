// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

import {KlasterProxy} from "./KlasterProxy.sol";
import {IKlasterProxy} from "../interface/IKlasterProxy.sol";
import {IKlasterProxyFactory} from "../interface/IKlasterProxyFactory.sol";
import {CCIPLaneProvider} from "../CCIPLaneProvider.sol";

contract KlasterProxyFactory is IKlasterProxyFactory, CCIPLaneProvider, CCIPReceiver {

    mapping (address => bool) public deployed;
    mapping (address => string) public salts; // proxy => salt
    mapping (address => address[]) public instances; // user => proxies[] 

    constructor() CCIPReceiver(_getRouterAddy(block.chainid)) {}
    
    function deploy(string memory salt) public returns (address) {
       return _deploy(msg.sender, salt);
    }

    function execute(
        uint256 chainId,
        string memory salt,
        address destination,
        uint value,
        bytes memory data,
        uint256 gasLimit
    ) external payable returns (bool success, bytes32 messageId) {
        if (chainId == block.chainid) { // execute on this chain
            success = _execute(msg.sender, salt, destination, value, data);
        } else { // remote execution on target chain via CCIP
            require(supportedChains[block.chainid].router != address(0), "Source chain not supported.");
            require(supportedChains[chainId].router != address(0), "Destination chain not supported.");
            
            // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                address(this),
                abi.encode(msg.sender, salt, destination, value, data),
                address(0),
                gasLimit
            );

            // Get the fee required to send the CCIP message
            uint256 fees = IRouterClient(
                supportedChains[block.chainid].router
            ).getFee(
                supportedChains[chainId].selector, evm2AnyMessage
            );
            require(address(this).balance >= fees, "Ether amount too low. Send more ether to execute ccip call.");
            
            success = true;
            messageId = IRouterClient(supportedChains[block.chainid].router).ccipSend{value: fees}(
                supportedChains[chainId].selector,
                evm2AnyMessage
            );
            
            emit SendRTC(
                messageId,
                supportedChains[chainId].selector,
                msg.sender,
                destination,
                address(0),
                fees
            );
        }
    }

    function calculateFee(
        address caller,
        uint256 chainId,
        string memory salt,
        address destination,
        uint value,
        bytes memory data,
        uint256 gasLimit
    ) external view returns (uint256) {
        if (chainId == block.chainid) { return 0; } 
        else {
            require(supportedChains[block.chainid].router != address(0), "Source chain not supported.");
            require(supportedChains[chainId].router != address(0), "Destination chain not supported.");
            
            // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                address(this),
                abi.encode(caller, salt, destination, value, data),
                address(0),
                gasLimit
            );

            // Get the fee required to send the CCIP message
            return IRouterClient(
                supportedChains[block.chainid].router
            ).getFee(
                supportedChains[chainId].selector, evm2AnyMessage
            );
        }
    }

    function calculateAddress(address owner, string memory salt) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), keccak256(abi.encodePacked(owner, salt)), keccak256(_getBytecode(owner))
            )
        );
        return address(uint160(uint(hash)));
    }

    // executes given action on the callers proxy wallet
    function _execute(
        address caller,
        string memory salt,
        address destination,
        uint value,
        bytes memory data
    ) internal returns (bool status) {
        address proxyInstanceAddress = calculateAddress(caller, salt);
        if (!deployed[proxyInstanceAddress]) { _deploy(caller, salt); }
        
        IKlasterProxy proxyInstance = IKlasterProxy(proxyInstanceAddress);
        require(proxyInstance.owner() == caller, "Not an owner!");

        status = proxyInstance.execute(destination, value, data);
        emit Execute(caller, proxyInstanceAddress, destination, status);
    }

    // deploys new proxy wallet for given owner and salt
    function _deploy(address owner, string memory salt) private returns (address proxyInstance) {
        require(!deployed[calculateAddress(owner, salt)], "Already deployed! Use different salt!");
        
        bytes memory bytecode = _getBytecode(owner);
        bytes32 calculatedSalt = keccak256(abi.encodePacked(owner, salt));
        assembly {
            proxyInstance := create2(0, add(bytecode, 32), mload(bytecode), calculatedSalt)
        }
        deployed[proxyInstance] = true;
        salts[proxyInstance] = salt;
        instances[owner].push(proxyInstance);
        
        emit ProxyDeploy(owner, proxyInstance);
    }

    // get the bytecode of the contract KlasterProxy with encoded constructor
    function _getBytecode(address owner) private pure returns (bytes memory) {
        bytes memory bytecode = type(KlasterProxy).creationCode;
        return abi.encodePacked(bytecode, abi.encode(owner));
    }

    // @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending arbitrary bytes cross chain.
    /// @param _receiver The address of the receiver.
    /// @param _message The bytes data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @param _gasLimit Gas limit.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _message,
        address _feeTokenAddress,
        uint256 _gasLimit
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: _message, // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: _gasLimit, strict: false})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
        return evm2AnyMessage;
    }

    /// handle received execution message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {
        require(
            abi.decode(any2EvmMessage.sender, (address)) == address(this),
            "Only official KlasterProxyFactory can send CCIP messages."
        );

        (
            address caller,
            string memory salt,
            address destination,
            uint256 value,
            bytes memory data
        ) = abi.decode(
            any2EvmMessage.data,
            (
                address,
                string,
                address,
                uint256,
                bytes
            )
        );

        _execute(caller, salt, destination, value, data);
        emit ReceiveRTC(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            caller,
            destination
        );
    }

}
