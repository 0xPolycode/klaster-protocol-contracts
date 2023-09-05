// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ConfirmedOwnerWithProposal} from "@chainlink/contracts-ccip/src/v0.8/ConfirmedOwner.sol";
import {ConfirmedOwner} from "@chainlink/contracts-ccip/src/v0.8/ConfirmedOwner.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract KlasterProxy is ConfirmedOwner {

    address public klasterProxyFactory;

    constructor(address _owner) ConfirmedOwner(_owner) {
        klasterProxyFactory = msg.sender;
    }

    function execute(
        address destination,
        uint value,
        bytes memory data
    ) external returns (bool) {
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
        return result;
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

}
