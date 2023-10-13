// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterGatewayWallet {

    function execute(
        address destination,
        uint256 value,
        bytes memory data
    ) external returns (bool, address);

    function executeWithData(
        address destination,
        uint256 value,
        bytes memory data,
        bytes32 extraData
    ) external returns (bool, address);

}
