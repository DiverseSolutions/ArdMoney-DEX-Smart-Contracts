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

contract RouterLiquidityFacet {
  RouterDiamondStorage internal routerData;
  using ArdMoneySafeMath for uint256;

  modifier ensure(uint256 deadline) {
    require(deadline >= block.timestamp, "EXPIRED");
    _;
  }

  // **** ADD LIQUIDITY ****
  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin
  ) internal returns (uint256 amountA, uint256 amountB) {
    // create the pair if it doesn't exist yet
    require(IArdMoneyFactory(routerData.factory).getPair(tokenA, tokenB) != address(0),"PAIR DOESN'T EXIST");
    (uint256 reserveA, uint256 reserveB) = ArdMoneyLibrary.getReserves(
      routerData.factory,
      tokenA,
      tokenB
    );
    if (reserveA == 0 && reserveB == 0) {
      (amountA, amountB) = (amountADesired, amountBDesired);
    } else {
      uint256 amountBOptimal = ArdMoneyLibrary.quote(
        amountADesired,
        reserveA,
        reserveB
      );
      if (amountBOptimal <= amountBDesired) {
        require(
          amountBOptimal >= amountBMin,
          "INSUFFICIENT_B_AMOUNT"
        );
        (amountA, amountB) = (amountADesired, amountBOptimal);
      } else {
        uint256 amountAOptimal = ArdMoneyLibrary.quote(
          amountBDesired,
          reserveB,
          reserveA
        );
        assert(amountAOptimal <= amountADesired);
        require(
          amountAOptimal >= amountAMin,
          "INSUFFICIENT_A_AMOUNT"
        );
        (amountA, amountB) = (amountAOptimal, amountBDesired);
      }
    }
  }

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  )
  external
  ensure(deadline)
  returns (
    uint256 amountA,
    uint256 amountB,
    uint256 liquidity
  )
  {
    (amountA, amountB) = _addLiquidity(
      tokenA,
      tokenB,
      amountADesired,
      amountBDesired,
      amountAMin,
      amountBMin
    );
    address pair = ArdMoneyLibrary.pairFor(routerData.factory, tokenA, tokenB);
    ArdMoneyTransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
    ArdMoneyTransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
    liquidity = IArdMoneyPair(pair).mint(to);
  }

  function addLiquidityETH(
    address token,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  )
  external
  payable
  ensure(deadline)
  returns (
    uint256 amountToken,
    uint256 amountETH,
    uint256 liquidity
  )
  {
    (amountToken, amountETH) = _addLiquidity(
      token,
      routerData.WETH,
      amountTokenDesired,
      msg.value,
      amountTokenMin,
      amountETHMin
    );
    address pair = ArdMoneyLibrary.pairFor(routerData.factory, token, routerData.WETH);
    ArdMoneyTransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
    IArdMoneyWETH(routerData.WETH).deposit{value: amountETH}();
    assert(IArdMoneyWETH(routerData.WETH).transfer(pair, amountETH));
    liquidity = IArdMoneyPair(pair).mint(to);
    // refund dust eth, if any
    if (msg.value > amountETH)
      ArdMoneyTransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
  }

  // **** REMOVE LIQUIDITY ****
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  )
  public
  ensure(deadline)
  returns (uint256 amountA, uint256 amountB)
  {
    address pair = ArdMoneyLibrary.pairFor(routerData.factory, tokenA, tokenB);
    IArdMoneyPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
    (uint256 amount0, uint256 amount1) = IArdMoneyPair(pair).burn(to);
    (address token0, ) = ArdMoneyLibrary.sortTokens(tokenA, tokenB);
    (amountA, amountB) = tokenA == token0
      ? (amount0, amount1)
      : (amount1, amount0);
      require(
        amountA >= amountAMin,
        "INSUFFICIENT_A_AMOUNT"
      );
      require(
        amountB >= amountBMin,
        "INSUFFICIENT_B_AMOUNT"
      );
  }

  function removeLiquidityETH(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  )
  public
  ensure(deadline)
  returns (uint256 amountToken, uint256 amountETH)
  {
    (amountToken, amountETH) = removeLiquidity(
      token,
      routerData.WETH,
      liquidity,
      amountTokenMin,
      amountETHMin,
      address(this),
      deadline
    );
    ArdMoneyTransferHelper.safeTransfer(token, to, amountToken);
    IArdMoneyWETH(routerData.WETH).withdraw(amountETH);
    ArdMoneyTransferHelper.safeTransferETH(to, amountETH);
  }

  function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 amountA, uint256 amountB) {
    address pair = ArdMoneyLibrary.pairFor(routerData.factory, tokenA, tokenB);
    uint256 value = approveMax ? uint256(-1) : liquidity;
    IArdMoneyPair(pair).permit(
      msg.sender,
      address(this),
      value,
      deadline,
      v,
      r,
      s
    );
    (amountA, amountB) = removeLiquidity(
      tokenA,
      tokenB,
      liquidity,
      amountAMin,
      amountBMin,
      to,
      deadline
    );
  }

  function removeLiquidityETHWithPermit(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
  external
  returns (uint256 amountToken, uint256 amountETH)
  {
    address pair = ArdMoneyLibrary.pairFor(routerData.factory, token, routerData.WETH);
    uint256 value = approveMax ? uint256(-1) : liquidity;
    IArdMoneyPair(pair).permit(
      msg.sender,
      address(this),
      value,
      deadline,
      v,
      r,
      s
    );
    (amountToken, amountETH) = removeLiquidityETH(
      token,
      liquidity,
      amountTokenMin,
      amountETHMin,
      to,
      deadline
    );
  }

  // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) public ensure(deadline) returns (uint256 amountETH) {
    (, amountETH) = removeLiquidity(
      token,
      routerData.WETH,
      liquidity,
      amountTokenMin,
      amountETHMin,
      address(this),
      deadline
    );
    ArdMoneyTransferHelper.safeTransfer(
      token,
      to,
      IArdMoneyERC20(token).balanceOf(address(this))
    );
    IArdMoneyWETH(routerData.WETH).withdraw(amountETH);
    ArdMoneyTransferHelper.safeTransferETH(to, amountETH);
  }

  function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 amountETH) {
    address pair = ArdMoneyLibrary.pairFor(routerData.factory, token, routerData.WETH);
    uint256 value = approveMax ? uint256(-1) : liquidity;
    IArdMoneyPair(pair).permit(
      msg.sender,
      address(this),
      value,
      deadline,
      v,
      r,
      s
    );
    amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
      token,
      liquidity,
      amountTokenMin,
      amountETHMin,
      to,
      deadline
    );
  }
}
