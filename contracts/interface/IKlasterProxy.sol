// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterProxy {

    function execute(
        address destination,
        uint value,
        bytes memory data
    ) external returns (bool);

    function executeWithSignature(
        address destination,
        uint value,
        bytes memory data,
        bytes32 messageHash
    ) external returns (bool);

    function owner() external view returns (address);

}
