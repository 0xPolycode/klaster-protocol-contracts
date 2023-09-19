// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/access/OwnableUpgradeable.sol";

import "./interface/ICCIPLaneProvider.sol";

contract CCIPLaneProvider is ICCIPLaneProvider, Initializable, UUPSUpgradeable, OwnableUpgradeable {

    ChainConfig[] public supportedChainsList;
    mapping (uint256 => ChainConfig) public supportedChains; // (chainId -> chainDef) mapping
    
    constructor() {}

    function initialize(address owner) external initializer {
        __Ownable_init();
        _transferOwnership(owner);
        _addSupportedChains();
    }

    function isChainSupported(uint256 chainId) external view override returns (bool) {
        return (supportedChains[chainId].router != address(0));
    }

    function getSupportedChains() external view override returns (ChainConfig[] memory) { return supportedChainsList; }

    function getChainConfig(uint256 chainId) external view override returns (ChainConfig memory) {
        return supportedChains[chainId];
    }

    function updateLane(
        uint256 laneIndex,
        string memory name,
        address router,
        uint64 chainSelector
    ) external onlyOwner {
        ChainConfig memory oldConfig = supportedChainsList[laneIndex];
        ChainConfig memory newConfig = ChainConfig(
            name, router, chainSelector, oldConfig.chainId
        );
        supportedChainsList[laneIndex] = newConfig;
        supportedChains[newConfig.chainId] = newConfig;
    }

    function addLane(string memory name, address router, uint64 chainSelector, uint256 chainId) external onlyOwner {
        require(supportedChains[chainId].router == address(0), "lane already exists");
        ChainConfig memory config = ChainConfig(name, router, chainSelector, chainId);
        supportedChains[chainId] = config;
        supportedChainsList.push(config);
    }

    // configure CCIP lanes based on the environment chain id
    function _addSupportedChains() internal {
        // add ccip based on the current chain id
        uint256 chainId = block.chainid;
        if (chainId == 1) {
            _enableLane(1);
            _enableLane(10);
            _enableLane(137);
            _enableLane(43114);
        }
        else if (chainId == 10) {
            _enableLane(1);
            _enableLane(10);
        }
        else if (chainId == 97) {
            _enableLane(97);
            _enableLane(11155111);
        }
        else if (chainId == 137) {
            _enableLane(1);
            _enableLane(137);
            _enableLane(43114);
        }
        else if (chainId == 420) {
            _enableLane(420);
            _enableLane(43113);
            _enableLane(421613);
            _enableLane(11155111);
        }
        else if (chainId == 43113) {
            _enableLane(420);
            _enableLane(43113);
            _enableLane(80001);
            _enableLane(11155111);
        }
        else if (chainId == 43114) {
            _enableLane(1);
            _enableLane(137);
            _enableLane(43114);
        }
        else if (chainId == 80001) {
            _enableLane(43113);
            _enableLane(80001);
            _enableLane(11155111);
        }
        else if (chainId == 84531) {
            _enableLane(84531);
            _enableLane(11155111);
        }
        else if (chainId == 421613) {
            _enableLane(420);
            _enableLane(421613);
            _enableLane(11155111);
        }
        else if (chainId == 11155111) {
            _enableLane(97);
            _enableLane(420);
            _enableLane(80001);
            _enableLane(43113);
            _enableLane(84531);
            _enableLane(421613);
            _enableLane(11155111);
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
        if (chainId == 1)           { return ChainConfig("Ethereum", _getRouterAddy(1), 5009297550715157269, 1); }
        if (chainId == 10)          { return ChainConfig("Optimism", _getRouterAddy(10), 3734403246176062136, 10); }
        if (chainId == 97)          { return ChainConfig("BNB Testnet", _getRouterAddy(97), 13264668187771770619, 97); }
        if (chainId == 137)         { return ChainConfig("Polygon", _getRouterAddy(137), 4051577828743386545, 137); }
        if (chainId == 420)         { return ChainConfig("Optimism Goerli", _getRouterAddy(420), 2664363617261496610, 420); }
        if (chainId == 43113)       { return ChainConfig("Avax Fuji", _getRouterAddy(43113), 14767482510784806043, 43113); }
        if (chainId == 43114)       { return ChainConfig("Avax", _getRouterAddy(43114), 6433500567565415381, 43114); }
        if (chainId == 80001)       { return ChainConfig("Polygon Mumbai", _getRouterAddy(80001), 12532609583862916517, 80001); }
        if (chainId == 84531)       { return ChainConfig("Base Goerli", _getRouterAddy(84531), 5790810961207155433, 84531); }
        if (chainId == 421613)      { return ChainConfig("Arbitrum Goerli", _getRouterAddy(421613), 6101244977088475029, 421613); }
        if (chainId == 11155111)    { return ChainConfig("Sepolia Testnet", _getRouterAddy(11155111), 16015286601757825753, 11155111); }
        else { revert("Unsupported CCIP lane!"); }
    }

    // CCIP testnet router addresses
    function _getRouterAddy(uint256 chainId) internal pure returns (address router) {
        if (chainId == 1)           { router = 0xE561d5E02207fb5eB32cca20a699E0d8919a1476; }
        if (chainId == 10)          { router = 0x261c05167db67B2b619f9d312e0753f3721ad6E8; }
        if (chainId == 97)          { router = 0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2; }
        if (chainId == 137)         { router = 0x3C3D92629A02a8D95D5CB9650fe49C3544f69B43; }
        if (chainId == 420)         { router = 0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26; }
        if (chainId == 43113)       { router = 0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8; }
        if (chainId == 43114)       { router = 0x27F39D0af3303703750D4001fCc1844c6491563c; }
        if (chainId == 80001)       { router = 0x70499c328e1E2a3c41108bd3730F6670a44595D1; }
        if (chainId == 84531)       { router = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; }
        if (chainId == 421613)      { router = 0x88E492127709447A5ABEFdaB8788a15B4567589E; }
        if (chainId == 11155111)    { router = 0xD0daae2231E9CB96b94C8512223533293C3693Bf; }
    }

    /**
     * UUPSUpgradeable
     */

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}
