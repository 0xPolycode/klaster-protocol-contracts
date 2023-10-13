// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC1271} from "../interface/IERC1271.sol";
import {IKlasterProxy} from "../interface/IKlasterProxy.sol";

contract KlasterProxy is Ownable, IERC1271, IKlasterProxy {

    address public klasterProxyFactory;

    mapping (bytes32 => bool) public signatures;

    constructor(address _owner) {
        klasterProxyFactory = msg.sender;
        _transferOwnership(_owner);
    }

    function executeWithData(
        address destination,
        uint256 value,
        bytes memory data,
        bytes32 extraData
    ) external returns (bool, address) {
        if (destination == address(0)) { // contract deployment
            if (extraData == "") { // deploy using create()
                return (true, _performCreate(value, data));
            } else { // deploy using create2()
                return (true, _performCreate2(value, data, extraData));
            }
        } else { // transaction execution (use extra data as contract wallet signature as per ERC-1271)
            if (extraData != "") { signatures[extraData] = true; }
            return execute(destination, value, data);
        }
    }

    function execute(
        address destination,
        uint256 value,
        bytes memory data
    ) public returns (bool, address) {
        require(
            msg.sender == klasterProxyFactory || msg.sender == owner(),
            "Not an owner!"
        );
        bool result;
        uint dataLength = data.length;
        assembly {
            let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
                sub(gas(), 34710),   // 34710 is the value that solidity is currently emitting
                                   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                destination,
                value,
                d,
                dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0                  // Output is ignored, therefore the output size is zero
            )
        }
        return (result, address(0));
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4 magicValue) {
        if (signatures[_hash]) {
            magicValue = 0x1626ba7e; // ERC1271: valid signature = bytes4(keccak256("isValidSignature(bytes32,bytes)")
        }
    }

    function _performCreate(
        uint256 value,
        bytes memory deploymentData
    ) internal returns (address newContract) {
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            newContract := create(value, add(deploymentData, 0x20), mload(deploymentData))
        }
        /* solhint-enable no-inline-assembly */
        require(newContract != address(0), "Could not deploy contract");
    }

    function _performCreate2(
        uint256 value,
        bytes memory deploymentData,
        bytes32 salt
    ) internal returns (address newContract) {
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            newContract := create2(value, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        /* solhint-enable no-inline-assembly */
        require(newContract != address(0), "Could not deploy contract");
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

}
