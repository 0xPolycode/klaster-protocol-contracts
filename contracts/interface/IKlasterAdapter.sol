// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterAdapter {
    function execute(
        uint256 sourceChainId,
        address sourceChainCaller,
        bytes calldata callData,
        bool bridgeBack
    ) external returns (bool success);
}
