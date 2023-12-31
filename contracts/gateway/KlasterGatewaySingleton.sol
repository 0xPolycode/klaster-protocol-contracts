// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {KlasterGatewayWallet} from "./KlasterGatewayWallet.sol";
import {IKlasterGatewayWallet} from "../interface/IKlasterGatewayWallet.sol";
import {IKlasterGatewaySingleton} from "../interface/IKlasterGatewaySingleton.sol";
import {IERC1271} from "../interface/IERC1271.sol";
import {IOwnable} from "../interface/IOwnable.sol";

contract KlasterGatewaySingleton is IKlasterGatewaySingleton, CCIPReceiver, AccessControl {

    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant HARVEST_MANAGER_ROLE = keccak256("HARVEST_MANAGER_ROLE");
    bytes32 public constant CCIP_MANAGER_ROLE = keccak256("CCIP_MANAGER_ROLE");

    uint256 public feePercentage; // percentage fee on top of the ccip fees (modifiable by the owner)
    uint64 public thisChainSelector; // current chain selector
    uint64 public relayerChainSelector; // relayer chain selector (sepolia for testnet, eth for mainnet)
    
    mapping (address => bool) public deployed;
    mapping (address => uint64) public controllingChains; // gateway wallet => controlling chain id
    mapping (address => string) public salts; // gateway wallet => salt
    mapping (address => address[]) public instances; // user => gateway wallet[]

    constructor(
        address _sourceRouter,
        uint64 _thisChainSelector,
        uint64 _relayerChainSelector,
        address _roleManager,
        address _ccipManager,
        address _harvestManager,
        address _feeManager,
        uint256 _feePercentage
    ) CCIPReceiver(_sourceRouter) {
        thisChainSelector = _thisChainSelector;
        relayerChainSelector = _relayerChainSelector;
        feePercentage = _feePercentage;
        _grantRole(DEFAULT_ADMIN_ROLE, _roleManager);
        _grantRole(FEE_MANAGER_ROLE, _feeManager);
        _grantRole(HARVEST_MANAGER_ROLE, _harvestManager);
        _grantRole(CCIP_MANAGER_ROLE, _ccipManager);

        // sanity checks
        require(
            _relayerChainSelector == _thisChainSelector ||
            IRouterClient(getRouter()).isChainSupported(relayerChainSelector),
            "Invalid relayer chain configuration."
        );
        require(_feeManager != address(0), "Fee manager is 0x0");
        require(_ccipManager != address(0), "CCIP manager is 0x0");
    }

    function deploy(string memory salt) public override returns (address) {
       return _deploy(msg.sender, salt, thisChainSelector);
    }

    /***
     * FEE_MANAGER FUNCTIONS (SENSITIVE)
     * 
     * Append only. Cant break anything or shut down the service.
     * KlasterGatewayWallet wallets will always work and in that sense it's permissionless.
     * The only two things a fee manager can affect and change post deployment are:
     *     1) Update platform fee - CAPPED TO 100% of the CCIP fee (!)
     *     2) Withdraw platform fee earnings
     */
    function updateFee(uint256 _feePercentage) external {
        require(hasRole(FEE_MANAGER_ROLE, msg.sender), "Caller is not a fee manager.");
        require(_feePercentage <= 100, "Platform fee is capped to 100% of the CCIP fee.");
        feePercentage = _feePercentage;
    }

    function withdraw(uint256 amount) external {
        require(hasRole(HARVEST_MANAGER_ROLE, msg.sender), "Caller is not a harvest manager.");
        payable(msg.sender).transfer(amount);
    }

    /***
     * CCIP_MANAGER FUNCTIONS (SENSITIVE)
     * 
     * CCIP manager is the only address that can update the router addresses.
     * This is a temporary role to be used only once. Chainlink's CCIP team is going to deploy
     * new router addresses after the GA launch, and this function will be used to store the new
     * router address and replace the old ones. After the update is complete, CCIP manager will renounce
     * its role.
     */
    function updateRouter(address _newRouterAddress) external {
        require(hasRole(CCIP_MANAGER_ROLE, msg.sender), "Caller is not a ccip manager.");
        i_router = _newRouterAddress;
    }

    /************ PUBLIC WRITE FUNCTIONS ************/

    function batchExecute(
        uint64[][] memory execChainSelectors,
        string[] memory salt,
        address[] memory destination,
        uint256[] memory value,
        bytes[] memory data,
        uint256[] memory gasLimit,
        bytes32[] memory extraData
    ) external payable override returns (bool[] memory success, address[] memory contractDeployed, bytes32[] memory messageId) {
        success = new bool[](execChainSelectors.length);
        contractDeployed = new address[](execChainSelectors.length);
        messageId = new bytes32[](execChainSelectors.length);
        for (uint256 i = 0; i < execChainSelectors.length; i++) {
            (success[i], contractDeployed[i], messageId[i]) = execute(
                execChainSelectors[i],
                salt[i],
                destination[i],
                value[i],
                data[i],
                gasLimit[i],
                extraData[i]
            );
        }
    }

    function execute(
        uint64[] memory execChainSelectors,
        string memory salt,
        address destination,
        uint256 value,
        bytes memory data,
        uint256 gasLimit,
        bytes32 extraData
    ) public payable override returns (bool success, address contractDeployed, bytes32 messageId) {
        
        if (destination != address(0) && extraData != "") { // if executing contract call (destination != 0) and extra data exists, then verify if the extra data is a valid signature
            require(
                IERC1271(msg.sender).isValidSignature(
                    extraData,
                    ""
                ) == 0x1626ba7e, // ERC1271: valid signature = bytes4(keccak256("isValidSignature(bytes32,bytes)")
                "Invalid signature."
            );
        }

        for (uint256 i = 0; i < execChainSelectors.length; i++) {
            (success, contractDeployed, messageId) = _execute(
                ExecutionData(
                    msg.sender,
                    thisChainSelector,
                    execChainSelectors[i],
                    salt,
                    destination,
                    value,
                    data,
                    gasLimit,
                    extraData,
                    true
                )
            );
        }
    }

    /************ PUBLIC READ FUNCTIONS ************/

    function getDeployedWallets(address owner) external view override returns (address[] memory) {
        return instances[owner];
    }

    function calculateBatchExecuteFee(
        address caller,
        uint64[][] memory execChainSelectors,
        string[] memory salt,
        address[] memory destination,
        uint256[] memory value,
        bytes[] memory data,
        uint256[] memory gasLimit,
        bytes32[] memory extraData
    ) external view override returns (uint256 totalFee) {
        for (uint256 i = 0; i < execChainSelectors.length; i++) {
            totalFee += calculateExecuteFee(
                caller,
                execChainSelectors[i],
                salt[i],
                destination[i],
                value[i],
                data[i],
                gasLimit[i],
                extraData[i]
            );
        }
    }

    function calculateExecuteFee(
        address caller,
        uint64[] memory execChainSelectors,
        string memory salt,
        address destination,
        uint256 value,
        bytes memory data,
        uint256 gasLimit,
        bytes32 extraData
    ) public view override returns (uint256 totalFee) {
        for (uint256 i = 0; i < execChainSelectors.length; i++) {
            uint64 execChainSelector = execChainSelectors[i];
            if (execChainSelector != thisChainSelector) {
                // Get available lane    
                uint64 destChainSelector = _getDestChainSelector(execChainSelector);
        
                // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
                Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                    address(this),
                    abi.encode(caller, thisChainSelector, execChainSelector, salt, destination, value, data, gasLimit, extraData),
                    address(0),
                    gasLimit
                );

                (, uint256 fee) = _getFees(destChainSelector, execChainSelector, evm2AnyMessage);
                totalFee += fee;
            }
        }
    }

    function calculateAddress(address owner, string memory salt) public view override returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), keccak256(abi.encodePacked(owner, salt)), keccak256(_getBytecode(owner))
            )
        );
        return address(uint160(uint(hash)));
    }

    function calculateCreate2Address(
        address owner,
        string memory salt,
        bytes memory byteCode,
        bytes32 create2Salt
    ) external view override returns (address) {
        bytes32 hash_ = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                calculateAddress(owner, salt),
                create2Salt,
                keccak256(byteCode)
            )
        );
        return address(uint160(uint256(hash_)));
    }

    /************ INTERNAL FUNCTIONS ************/
    
    struct ExecutionData {
        address caller;
        uint64 sourceChainSelector;
        uint64 execChainSelector;
        string salt;
        address destination;
        uint256 value;
        bytes data;
        uint256 gasLimit;
        bytes32 extraData;
        bool feeEnabled;
    }
    function _execute(
        ExecutionData memory execData
    ) internal returns (bool success, address contractDeployed, bytes32 messageId) {
        if (execData.execChainSelector == thisChainSelector) { // execute on this chain
            (success, contractDeployed) = _executeOnWallet(
                execData.sourceChainSelector,
                execData.caller,
                execData.salt,
                execData.destination,
                execData.value,
                execData.data,
                execData.extraData
            );
        } else { // remote execution on target chain via CCIP

            // Get available lane  
            uint64 destChainSelector = _getDestChainSelector(execData.execChainSelector);

            // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                address(this),
                abi.encode(
                    execData.caller,
                    execData.sourceChainSelector,
                    execData.execChainSelector,
                    execData.salt,
                    execData.destination,
                    execData.value,
                    execData.data,
                    execData.gasLimit,
                    execData.extraData
                ),
                address(0),
                execData.gasLimit
            );

            (uint256 ccipFees, uint256 totalFee) = _getFees(
                destChainSelector,
                execData.execChainSelector,
                evm2AnyMessage
            );

            // Take into account platform fee
            if (execData.feeEnabled) {
                require(msg.value >= totalFee, "Ether amount too low. Send more ether to execute call.");
            }
            
            success = true;
            messageId = IRouterClient(getRouter()).ccipSend{value: ccipFees}(
                destChainSelector,
                evm2AnyMessage
            );

            emit SendRTC(
                    messageId,
                    execData.caller,
                    destChainSelector,
                    execData.execChainSelector,
                    execData.destination,
                    execData.extraData,
                    address(0),
                    ccipFees,
                    totalFee
            );
        }
    }

    // executes given action on the callers gateway wallet
    function _executeOnWallet(
        uint64 sourceChainSelector,
        address caller,
        string memory salt,
        address destination,
        uint256 value,
        bytes memory data,
        bytes32 extraData
    ) internal returns (bool status, address contractDeployed) {
        address walletInstanceAddress = calculateAddress(caller, salt);
        if (!deployed[walletInstanceAddress]) {
            _deploy(caller, salt, sourceChainSelector);
        } else {
            require(
                sourceChainSelector == controllingChains[walletInstanceAddress],
                "Can only execute from controlling chain."
            );
        }
        
        IKlasterGatewayWallet walletInstance = IKlasterGatewayWallet(walletInstanceAddress);
        
        require(IOwnable(walletInstanceAddress).owner() == caller, "Not an owner!");
        (status, contractDeployed) = walletInstance.executeWithData(destination, value, data, extraData);
        
        emit Execute(caller, walletInstanceAddress, destination, status, contractDeployed, extraData);
    }

    // deploys new gateway wallet for given owner and salt
    function _deploy(
        address owner,
        string memory salt,
        uint64 sourceChainSelector
    ) private returns (address walletInstance) {
        require(!deployed[calculateAddress(owner, salt)], "Already deployed! Use different salt!");
        
        bytes memory bytecode = _getBytecode(owner);
        bytes32 calculatedSalt = keccak256(abi.encodePacked(owner, salt));
        assembly {
            walletInstance := create2(0, add(bytecode, 32), mload(bytecode), calculatedSalt)
        }
        deployed[walletInstance] = true;
        salts[walletInstance] = salt;
        controllingChains[walletInstance] = sourceChainSelector;
        instances[owner].push(walletInstance);
        
        emit WalletDeploy(owner, walletInstance);
    }

    // get the bytecode of the contract KlasterGatewayWallet with encoded constructor
    function _getBytecode(address owner) private pure returns (bytes memory) {
        bytes memory bytecode = type(KlasterGatewayWallet).creationCode;
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
            "Only official KlasterGatewaySingleton can send CCIP messages."
        );

        (
            address caller,
            uint64 sourceChainSelector,
            uint64 execChainSelector,
            string memory salt,
            address destination,
            uint256 value,
            bytes memory data,
            uint256 gasLimit,
            bytes32 extraData
        ) = abi.decode(
            any2EvmMessage.data,
            (
                address,
                uint64,
                uint64,
                string,
                address,
                uint256,
                bytes,
                uint256,
                bytes32
            )
        );

        _execute(
            ExecutionData(
                caller,
                sourceChainSelector,
                execChainSelector,
                salt,
                destination,
                value,
                data,
                gasLimit,
                extraData,
                false
            )
        );

        emit ReceiveRTC(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            caller,
            destination,
            extraData
        );
    }

    function _getFees(
        uint64 destChainSelector,
        uint64 execChainSelector,
        Client.EVM2AnyMessage memory message
    ) internal view returns (uint256 ccipFee, uint256 totalFee) {
        // Multiply fees by 2 if not a direct lane
        uint256 laneMultiplier = (destChainSelector == execChainSelector) ? 1 : 2;
        ccipFee = IRouterClient(getRouter()).getFee(destChainSelector, message);
        totalFee = (ccipFee + (ccipFee * feePercentage / 100)) * laneMultiplier;
    }

    function _directLaneExists(uint64 execChainSelector) internal view returns (bool) {
        return IRouterClient(getRouter()).isChainSupported(execChainSelector);
    }
    
    function _getDestChainSelector(uint64 execChainSelector) internal view returns (uint64 selector) {
        selector = _directLaneExists(execChainSelector) ? execChainSelector : relayerChainSelector;
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    /// ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(CCIPReceiver, AccessControl) returns (bool) {
        return CCIPReceiver.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
}
