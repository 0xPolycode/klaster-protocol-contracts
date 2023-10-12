// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterProxyFactory {

    /************************** EVENTS **************************/

    // Event emitted when a new proxy wallet instance has been deployed.
    event ProxyDeploy(
        address indexed owner,
        address proxyInstance
    );
    
    // Event emitted when a message is sent to another chain.
    event SendRTC(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        address indexed caller, // Wallet initiating the RTC
        uint64 destinationChainSelector, // The chain selector of the destination chain.
        uint64 execChainSelector, // The chain selector of the execution chain.
        address targetContract, // Remote contract to execute on dest chain
        bytes32 messageHash,
        address feeToken, // the token address used to pay CCIP fees.
        uint256 ccipfees, // The fees paid for sending the CCIP message.
        uint256 totalFees // Total fees (ccip + platform fee)
    );

    // Event emitted when a message is received from another chain.
    event ReceiveRTC(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the destination chain.
        address caller, // Wallet initiating the RTC.
        address targetContract, // Remote contract to execute on dest chain,
        bytes32 messageHash
    );

    // Event emitted when any proxy wallet action gets executed
    event Execute(
        address indexed caller,
        address indexed proxyWallet,
        address indexed destination,
        bool status,
        address contractDeployed,
        bytes32 messageHash
    );

    /************************** WRITE **************************/

    function deploy(string memory salt) external returns (address);

    function batchExecute(
        uint64[][] memory execChainSelectors,
        string[] memory salt,
        address[] memory destination,
        uint256[] memory value,
        bytes[] memory data,
        uint256[] memory gasLimit,
        bytes32[] memory extraData
    ) external payable returns (bool[] memory, address[] memory, bytes32[] memory);

    function execute(
        uint64[] memory execChainSelectors,
        string memory salt,
        address destination,
        uint value,
        bytes memory data,
        uint256 gasLimit,
        bytes32 extraData
    ) external payable returns (bool, address, bytes32);

    /************************** READ **************************/

    function getDeployedProxies(address owner) external view returns (address[] memory);
    
    function calculateBatchExecuteFee(
        address caller,
        uint64[][] memory execChainSelectors,
        string[] memory salt,
        address[] memory destination,
        uint256[] memory value,
        bytes[] memory data,
        uint256[] memory gasLimit,
        bytes32[] memory extraData
    ) external view returns (uint256);

    function calculateExecuteFee(
        address caller,
        uint64[] memory execChainSelectors,
        string memory salt,
        address destination,
        uint value,
        bytes memory data,
        uint256 gasLimit,
        bytes32 extraData
    ) external view returns (uint256);

    function calculateAddress(address owner, string memory salt) external view returns (address);

}
