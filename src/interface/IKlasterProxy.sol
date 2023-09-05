// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IKlasterProxy {

    function execute(
        address destination,
        uint value,
        bytes memory data
    ) external returns (bool);

    function owner() external view returns (address);

}
