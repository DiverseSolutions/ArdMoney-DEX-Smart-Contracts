// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import { RouterDiamondStorage } from "../storage/RouterDiamondStorage.sol";

import "../interfaces/IArdMoneyFactory.sol";
import "../interfaces/IArdMoneyPair.sol";
import "../interfaces/IArdMoneyWETH.sol";
import "../interfaces/IArdMoneyERC20.sol";

import "../libraries/ArdMoneyLibrary.sol";
import "../libraries/ArdMoneySafeMath.sol";
import "../libraries/ArdMoneyTransferHelper.sol";

contract RouterSwapFacet {
  RouterDiamondStorage internal routerData;
  using ArdMoneySafeMath for uint256;

  modifier ensure(uint256 deadline) {
    require(deadline >= block.timestamp, "EXPIRED");
    _;
  }

  // **** SWAP ****
  // requires the initial amount to have already been sent to the first pair
  function _swap(
    uint256[] memory amounts,
    address[] memory path,
    address _to
  ) internal {
    for (uint256 i; i < path.length - 1; i++) {
      (address input, address output) = (path[i], path[i + 1]);
      (address token0, ) = ArdMoneyLibrary.sortTokens(input, output);
      uint256 amountOut = amounts[i + 1];
      (uint256 amount0Out, uint256 amount1Out) = input == token0
        ? (uint256(0), amountOut)
        : (amountOut, uint256(0));
        address to = i < path.length - 2
          ? ArdMoneyLibrary.pairFor(routerData.factory, output, path[i + 2])
          : _to;
          IArdMoneyPair(ArdMoneyLibrary.pairFor(routerData.factory, input, output))
          .swap(amount0Out, amount1Out, to, new bytes(0));
    }
  }

  /// @param amountIn Amount Of TokenA Willing To Swap For
  /// @param amountOutMin Minimum amount out TokenB willing to take
  /// @param path array of pair address , Ex: TokenA swap for TokenC route would be [TokenA/TokenB Pair Address,TokenB/TokenC Pair Address]
  /// @param to user address
  /// @param deadline epoch timestamp deadline - https://www.epochconverter.com/
  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  )
  external
  ensure(deadline)
  returns (uint256[] memory amounts)
  {
    amounts = ArdMoneyLibrary.getAmountsOut(routerData.factory, amountIn, path);
    require(
      amounts[amounts.length - 1] >= amountOutMin,
      "INSUFFICIENT_OUTPUT_AMOUNT"
    );
    ArdMoneyTransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
      amounts[0]
    );
    _swap(amounts, path, to);
  }

  /// @param amountOut Amount Of TokenB To Expect
  /// @param amountInMax Max Of Amount Of TokenA Willing To Trade For
  /// @param path array of pair address , Ex: TokenA swap for TokenC route would be [TokenA/TokenB Pair Address,TokenB/TokenC Pair Address]
  /// @param to user address
  /// @param deadline epoch timestamp deadline - https://www.epochconverter.com/
  function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  )
  external
  ensure(deadline)
  returns (uint256[] memory amounts)
  {
    amounts = ArdMoneyLibrary.getAmountsIn(routerData.factory, amountOut, path);
    require(
      amounts[0] <= amountInMax,
      "EXCESSIVE_INPUT_AMOUNT"
    );
    ArdMoneyTransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
      amounts[0]
    );
    _swap(amounts, path, to);
  }

  /// @dev Payable function henceforth sending ether for TokenA
  /// @param amountOutMin Minimum Amount Of TokenA Willing To Take
  /// @param path array of pair address , Ex: TokenA swap for TokenC route would be [TokenA/TokenB Pair Address,TokenB/TokenC Pair Address]
  /// @param to user address
  /// @param deadline epoch timestamp deadline - https://www.epochconverter.com/
  function swapExactETHForTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  )
  external
  payable
  ensure(deadline)
  returns (uint256[] memory amounts)
  {
    require(path[0] == routerData.WETH, "INVALID_PATH");
    amounts = ArdMoneyLibrary.getAmountsOut(routerData.factory, msg.value, path);
    require(
      amounts[amounts.length - 1] >= amountOutMin,
      "INSUFFICIENT_OUTPUT_AMOUNT"
    );
    IArdMoneyWETH(routerData.WETH).deposit{value: amounts[0]}();
    assert(
      IArdMoneyWETH(routerData.WETH).transfer(
        ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
        amounts[0]
    )
    );
    _swap(amounts, path, to);
  }

  /// @dev Give Token and Take Ether
  /// @param amountOut Amount Of Ether Willing To Take
  /// @param amountInMax ???
  /// @param path array of pair address , Ex: TokenA swap for TokenC route would be [TokenA/TokenB Pair Address,TokenB/TokenC Pair Address]
  /// @param to user address
  /// @param deadline epoch timestamp deadline - https://www.epochconverter.com/
  function swapTokensForExactETH(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  )
  external
  ensure(deadline)
  returns (uint256[] memory amounts)
  {
    require(path[path.length - 1] == routerData.WETH, "INVALID_PATH");
    amounts = ArdMoneyLibrary.getAmountsIn(routerData.factory, amountOut, path);
    require(
      amounts[0] <= amountInMax,
      "EXCESSIVE_INPUT_AMOUNT"
    );
    ArdMoneyTransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
      amounts[0]
    );
    _swap(amounts, path, address(this));
    IArdMoneyWETH(routerData.WETH).withdraw(amounts[amounts.length - 1]);
    ArdMoneyTransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
  }

  /// @dev Give Token and Take Ether
  /// @param amountIn Amount of token willing to swap for
  /// @param amountOutMin Minimum amount of ether willing to take
  /// @param path array of pair address , Ex: TokenA swap for TokenC route would be [TokenA/TokenB Pair Address,TokenB/TokenC Pair Address]
  /// @param to user address
  /// @param deadline epoch timestamp deadline - https://www.epochconverter.com/
  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  )
  external
  ensure(deadline)
  returns (uint256[] memory amounts)
  {
    require(path[path.length - 1] == routerData.WETH, "INVALID_PATH");
    amounts = ArdMoneyLibrary.getAmountsOut(routerData.factory, amountIn, path);
    require(
      amounts[amounts.length - 1] >= amountOutMin,
      "INSUFFICIENT_OUTPUT_AMOUNT"
    );
    ArdMoneyTransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
      amounts[0]
    );
    _swap(amounts, path, address(this));
    IArdMoneyWETH(routerData.WETH).withdraw(amounts[amounts.length - 1]);
    ArdMoneyTransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
  }

  /// @dev Give Ether and Take Token - Henceforth function payable
  /// @param amountOut Amount Of Token wanting to take
  /// @param path array of pair address , Ex: TokenA swap for TokenC route would be [TokenA/TokenB Pair Address,TokenB/TokenC Pair Address]
  /// @param to user address
  /// @param deadline epoch timestamp deadline - https://www.epochconverter.com/
  function swapETHForExactTokens(
    uint256 amountOut,
    address[] calldata path,
    address to,
    uint256 deadline
  )
  external
  payable
  ensure(deadline)
  returns (uint256[] memory amounts)
  {
    require(path[0] == routerData.WETH, "INVALID_PATH");
    amounts = ArdMoneyLibrary.getAmountsIn(routerData.factory, amountOut, path);
    require(
      amounts[0] <= msg.value,
      "EXCESSIVE_INPUT_AMOUNT"
    );
    IArdMoneyWETH(routerData.WETH).deposit{value: amounts[0]}();
    assert(
      IArdMoneyWETH(routerData.WETH).transfer(
        ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
        amounts[0]
    )
    );
    _swap(amounts, path, to);
    // refund dust eth, if any
    if (msg.value > amounts[0])
      ArdMoneyTransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
  }

  // **** SWAP (supporting fee-on-transfer tokens) ****
  // requires the initial amount to have already been sent to the first pair
  function _swapSupportingFeeOnTransferTokens(
    address[] memory path,
    address _to
  ) internal {
    for (uint256 i; i < path.length - 1; i++) {
      (address input, address output) = (path[i], path[i + 1]);
      (address token0, ) = ArdMoneyLibrary.sortTokens(input, output);
      IArdMoneyPair pair = IArdMoneyPair(
        ArdMoneyLibrary.pairFor(routerData.factory, input, output)
      );
      uint256 amountInput;
      uint256 amountOutput;
      {
        // scope to avoid stack too deep errors
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (uint256 reserveInput, uint256 reserveOutput) = input == token0
          ? (reserve0, reserve1)
          : (reserve1, reserve0);
          amountInput = IArdMoneyERC20(input).balanceOf(address(pair)).sub(
            reserveInput
          );
          uint256 swapFee =  IArdMoneyPair(ArdMoneyLibrary.pairFor(routerData.factory, input, output)).getSwapFee();
          amountOutput = ArdMoneyLibrary.getAmountOut(
            amountInput,
            reserveInput,
            reserveOutput,
            swapFee
          );
      }
      (uint256 amount0Out, uint256 amount1Out) = input == token0
        ? (uint256(0), amountOutput)
        : (amountOutput, uint256(0));
        address to = i < path.length - 2
          ? ArdMoneyLibrary.pairFor(routerData.factory, output, path[i + 2])
          : _to;
          pair.swap(amount0Out, amount1Out, to, new bytes(0));
    }
  }

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external ensure(deadline) {
    ArdMoneyTransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
      amountIn
    );
    uint256 balanceBefore = IArdMoneyERC20(path[path.length - 1]).balanceOf(
      to
    );
    _swapSupportingFeeOnTransferTokens(path, to);
    require(
      IArdMoneyERC20(path[path.length - 1]).balanceOf(to).sub(
        balanceBefore
    ) >= amountOutMin,
    "INSUFFICIENT_OUTPUT_AMOUNT"
    );
  }

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable ensure(deadline) {
    require(path[0] == routerData.WETH, "INVALID_PATH");
    uint256 amountIn = msg.value;
    IArdMoneyWETH(routerData.WETH).deposit{value: amountIn}();
    assert( IArdMoneyWETH(routerData.WETH).transfer( ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]), amountIn));
    uint256 balanceBefore = IArdMoneyERC20(path[path.length - 1]).balanceOf( to);
    _swapSupportingFeeOnTransferTokens(path, to);
    require(
      IArdMoneyERC20(path[path.length - 1]).balanceOf(to).sub(
        balanceBefore
    ) >= amountOutMin,
    "INSUFFICIENT_OUTPUT_AMOUNT"
    );
  }

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external ensure(deadline) {
    require(path[path.length - 1] == routerData.WETH, "INVALID_PATH");
    ArdMoneyTransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      ArdMoneyLibrary.pairFor(routerData.factory, path[0], path[1]),
      amountIn
    );
    _swapSupportingFeeOnTransferTokens(path, address(this));
    uint256 amountOut = IArdMoneyERC20(routerData.WETH).balanceOf(address(this));
    require(
      amountOut >= amountOutMin,
      "INSUFFICIENT_OUTPUT_AMOUNT"
    );
    IArdMoneyWETH(routerData.WETH).withdraw(amountOut);
    ArdMoneyTransferHelper.safeTransferETH(to, amountOut);
  }
}
