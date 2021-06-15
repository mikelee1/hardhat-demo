//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IUniswap.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapPool {
    address uniswap;
    

    constructor(address _uniswap) {
        uniswap = _uniswap;
    }

    function getFactory() external view returns (address){        
        return IUniswap(uniswap).factory();
    }

    function getWETH() external view returns (address){        
        return IUniswap(uniswap).WETH();
    }



    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        {
            console.log("value: ",msg.value);
            uint[] memory amounts = IUniswap(uniswap).swapExactETHForTokens{value:msg.value}(amountOutMin, path, to, deadline);
            // console.log("swapExactETHForTokens amounts: ",amounts);
            console.log(IERC20(path[1]).balanceOf(to));

        }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        {
            // console.log(IUniswap(uniswap).swapExactTokensForETH(amountIn,amountOutMin, path, to, deadline));
            uint[] memory amounts =IUniswap(uniswap).swapExactTokensForETH(amountIn,amountOutMin, path, to, deadline);
            // console.log("swapExactTokensForETH amounts: ",amounts);
        }
}
