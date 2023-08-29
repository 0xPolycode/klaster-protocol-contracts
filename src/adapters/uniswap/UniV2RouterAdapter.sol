// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

import {IThalamusERC20} from "../../interface/IThalamusERC20.sol";
import {IThalamusAdapter} from "../../interface/IThalamusAdapter.sol";

import {IUniswapV2Router01} from "./IUniV2Router.sol";

contract UniV2RouterAdapter is IThalamusAdapter {

    IUniswapV2Router01 public uniV2Router;

    constructor(IUniswapV2Router01 _uniV2Router) {
        uniV2Router = _uniV2Router;
    }

    function execute(
        uint256 sourceChainId,
        address sourceChainCaller, // not needed for univ2 adapter as uni asks for `to` param. but we keep this as an API for other protocols
        bytes calldata callData,
        bool bridgeBack
    ) external returns (bool success) {
        bytes4 fnSelector = bytes4(callData[:4]);
        if (fnSelector == 0x38ed1739) { // handle swapExactTokensForTokens()
            return _executeSwapExactTokensForTokens(sourceChainId, callData, bridgeBack);
        } else { // handler missing, return false
            return false;
        }
    }

    function _executeSwapExactTokensForTokens(
        uint256 sourceChainId,
        bytes calldata callData,
        bool bridgeBack
    ) internal returns (bool) {
        (
            uint256 amountIn,
            uint256 amountOutMin,
            address[] memory path,
            address to,
            uint256 deadline
        ) = abi.decode(callData[4:], (uint256, uint256, address[], address, uint256));
        
        uint[] memory amounts = uniV2Router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        IThalamusERC20 outToken = IThalamusERC20(path[path.length - 1]);
        uint256 outAmount = amounts[amounts.length - 1];
        
        if (outAmount > 0) {
            if (bridgeBack) {
                outToken.rtc(
                    sourceChainId,
                    outAmount,
                    to,
                    0, address(0), new bytes(0), 200_000, false
                );
            } else {
                outToken.transfer(to, outAmount);
            }
        }

        return true;
    }

}
