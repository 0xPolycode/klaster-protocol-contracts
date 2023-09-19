// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterProxyFactory {

    // Event emitted when a new proxy wallet instance has been deployed.
    event ProxyDeploy(
        address indexed owner,
        address proxyInstance
    );
    
    // Event emitted when a message is sent to another chain.
    event SendRTC(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address caller, // Wallet initiating the RTC
        address targetContract, // Remote contract to execute on dest chain
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    // Event emitted when a message is received from another chain.
    event ReceiveRTC(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the destination chain.
        address caller, // Wallet initiating the RTC.
        address targetContract // Remote contract to execute on dest chain
    );

    // Event emitted when any proxy wallet action gets executed
    event Execute(
        address indexed caller,
        address indexed proxyWallet,
        address indexed destination,
        bool status
    );

    function deploy(string memory salt) external returns (address);

    function execute(
        uint256 chainId,
        string memory salt,
        address destination,
        uint value,
        bytes memory data,
        uint256 gasLimit
    ) external payable returns (bool, bytes32); // [exec status, ccip message id or 0x0 if not cross-chain call]
    
    function calculateFee(
        address caller,
        uint256 chainId,
        string memory salt,
        address destination,
        uint value,
        bytes memory data,
        uint256 gasLimit
    ) external view returns (uint256);

    function calculateAddress(address owner, string memory salt) external view returns (address);

}
