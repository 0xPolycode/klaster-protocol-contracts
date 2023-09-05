// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract CCIPLaneProvider {

    struct ChainConfig {
        string name;
        address router;
        uint64 selector;
    }

    ChainConfig[] supportedChainsList;
    mapping (uint256 => ChainConfig) supportedChains; // (chainId -> chainDef) mapping
    
    constructor() {
        _addSupportedChains();
    }

    function getChainConfig(uint256 chainId) public view returns (ChainConfig memory) {
        return supportedChains[chainId];
    }

    function isChainSupported(uint256 chainId) public view returns (bool) {
        return (supportedChains[chainId].router != address(0));
    }

    function getSupportedChains() external view returns (ChainConfig[] memory) { return supportedChainsList; }

    // configure CCIP lanes based on the environment chain id
    function _addSupportedChains() internal {
        uint256 chainId = block.chainid;
        if (chainId == 1) {
            _enableLane(10);
            _enableLane(137);
            _enableLane(43114);
        }
        else if (chainId == 10) {
            _enableLane(1);   
        }
        else if (chainId == 137) {
            _enableLane(1);
            _enableLane(43114);
        }
        else if (chainId == 420) {
            _enableLane(43113);
            _enableLane(421613);
            _enableLane(11155111);
        }
        else if (chainId == 43113) {
            _enableLane(420);
            _enableLane(80001);
            _enableLane(11155111);
        }
        else if (chainId == 43114) {
            _enableLane(1);
            _enableLane(137);
        }
        else if (chainId == 80001) {
            _enableLane(43113);
            _enableLane(11155111);
        }
        else if (chainId == 421613) {
            _enableLane(420);
            _enableLane(11155111);
        }
        else if (chainId == 11155111) {
            _enableLane(420);
            _enableLane(80001);
            _enableLane(43113);
            _enableLane(421613);
        } else {
            revert("CCIP not supported on this blockchain network.");
        }
    }

    function _enableLane(uint256 chainId) internal {
        ChainConfig memory config = _getChainConfig(chainId);
        supportedChains[chainId] = config;
        supportedChainsList.push(config);
    }

    // CCIP testnet chain configs
    function _getChainConfig(
        uint256 chainId
    ) internal pure returns (ChainConfig memory) {
        if (chainId == 1)           { return ChainConfig("Ethereum", _getRouterAddy(1), 5009297550715157269); }
        if (chainId == 10)          { return ChainConfig("Optimism", _getRouterAddy(10), 3734403246176062136); }
        if (chainId == 137)         { return ChainConfig("Polygon", _getRouterAddy(137), 4051577828743386545); }
        if (chainId == 420)         { return ChainConfig("Optimism Goerli", _getRouterAddy(420), 2664363617261496610); }
        if (chainId == 43113)       { return ChainConfig("Avax Fuji", _getRouterAddy(43113), 14767482510784806043); }
        if (chainId == 43114)       { return ChainConfig("Avax", _getRouterAddy(43114), 6433500567565415381); }
        if (chainId == 80001)       { return ChainConfig("Polygon Mumbai", _getRouterAddy(80001), 12532609583862916517); }
        if (chainId == 421613)      { return ChainConfig("Arbitrum Goerli", _getRouterAddy(421613), 6101244977088475029); }
        if (chainId == 11155111)    { return ChainConfig("Sepolia Testnet", _getRouterAddy(11155111), 16015286601757825753); }
        else { revert("Unsupported CCIP lane!"); }
    }

    // CCIP testnet router addresses
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

}
