
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

interface IKlasterERC20 is IERC20 {

    // Event emitted when a message is sent to another chain.
    event SendRTC(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address messageSender, // Wallet initiating the RTC.
        uint256 bridgeAmount, // Amount of tokens bridged.
        address bridgeReceiver, // Wallet address receiving bridged tokens.
        uint256 allowanceAmount, // Amount of tokens bridged + approved.
        address contractAddress, // Remote contract to execute on dest chain
        bool bridgeBack, // Should bridge back tokens resulting after contract call?
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    // Event emitted when a message is received from another chain.
    event ReceiveRTC(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the destination chain.
        address messageSender, // Wallet initiating the RTC.
        uint256 bridgeAmount, // Amount of tokens bridged.
        address bridgeReceiver, // Wallet address receiving bridged tokens.
        uint256 allowanceAmount, // Amount of tokens bridged + approved.
        address contractAddress, // Remote contract to execute on dest chain
        bool bridgeBack // Should bridge back tokens resulting after contract call?
    );

    function rtc(
        uint256 chainId,
        uint256 bridgeAmount,
        address bridgeReceiver,
        uint256 allowanceAmount,
        address contractAddress,
        bytes memory callData,
        uint256 gasLimit,
        bool bridgeBack
    ) external payable returns (bytes32);

    function getRtcFee(
        uint256 chainId,
        uint256 bridgeAmount,
        address bridgeReceiver,
        uint256 allowanceAmount,
        address contractAddress,
        bytes memory callData,
        uint256 gasLimit,
        bool bridgeBack
    ) external view returns (uint256);

}
