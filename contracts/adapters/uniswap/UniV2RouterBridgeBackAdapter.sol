// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

import {IKlasterERC20} from "../../interface/IKlasterERC20.sol";
// import {IKlasterAdapter} from "../../interface/IKlasterAdapter.sol";

import {IUniswapV2Router01} from "./IUniV2Router.sol";

contract UniV2RouterBridgeBackAdapter {

    function execute(
        uint256 sourceChainId,
        address sourceChainCaller, // not needed for univ2 adapter as uni asks for `to` param. but we keep this as an API for other protocols
        address targetContract,
        bytes calldata callData
    ) external returns (bool success) {
        bytes4 fnSelector = bytes4(callData[:4]);
        if (fnSelector == 0x38ed1739) { // handle swapExactTokensForTokens()
            return _executeSwapExactTokensForTokens(sourceChainId, targetContract, callData);
        } else { // handler missing, return false
            return false;
        }
    }

    function _executeSwapExactTokensForTokens(
        uint256 sourceChainId,
        address targetContract,
        bytes calldata callData
    ) internal returns (bool) {
        (
            uint256 amountIn,
            uint256 amountOutMin,
            address[] memory path,
            address to,
            uint256 deadline
        ) = abi.decode(callData[4:], (uint256, uint256, address[], address, uint256));
        
        uint[] memory amounts = IUniswapV2Router01(targetContract).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        IKlasterERC20 outToken = IKlasterERC20(path[path.length - 1]);
        uint256 outAmount = amounts[amounts.length - 1];
        
        if (outAmount > 0) {
            outToken.rtc(
                sourceChainId,
                outAmount,
                to,
                0, address(0), new bytes(0), 200_000, false
            );
        }

        return true;
    }

}
