// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterAdapter {
    function execute(
        uint256 sourceChainId,
        address sourceChainCaller,
        address targetContract,
        bytes calldata callData
    ) external returns (bool success);
}
