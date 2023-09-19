// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface ICCIPLaneProvider {

    struct ChainConfig {
        string name;
        address router;
        uint64 selector;
        uint256 chainId;
    }

    function isChainSupported(uint256 chainId) external view returns (bool);
    function getSupportedChains() external view returns (ChainConfig[] memory);
    function getChainConfig(uint256 chainId) external view returns (ChainConfig memory);

}
