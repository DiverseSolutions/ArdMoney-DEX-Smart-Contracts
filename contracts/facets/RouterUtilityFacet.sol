// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import { RouterDiamondStorage } from "../storage/RouterDiamondStorage.sol";

import "../libraries/ArdMoneyLibrary.sol";

contract RouterUtilityFacet {
  RouterDiamondStorage internal routerData;

  // **** LIBRARY FUNCTIONS ****
  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) public pure returns (uint256 amountB) {
    return ArdMoneyLibrary.quote(amountA, reserveA, reserveB);
  }

  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut,
    uint256 swapFee
  ) public pure returns (uint256 amountOut) {
    return ArdMoneyLibrary.getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
  }

  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut,
    uint256 swapFee
  ) public pure returns (uint256 amountIn) {
    return ArdMoneyLibrary.getAmountIn(amountOut, reserveIn, reserveOut, swapFee);
  }

  function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
    return ArdMoneyLibrary.getAmountsOut(routerData.factory, amountIn, path);
  }

  function getAmountsIn(uint256 amountOut, address[] memory path) public view returns (uint256[] memory amounts) {
    return ArdMoneyLibrary.getAmountsIn(routerData.factory, amountOut, path);
  }

  function WETH() view external returns (address){
    return routerData.WETH;
  }

  function factory() view external returns (address){
    return routerData.factory;
  }

}
