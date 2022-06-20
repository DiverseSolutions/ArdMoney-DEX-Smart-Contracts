// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import "./libraries/ArdMoneyLibrary.sol";
import "./libraries/ArdMoneySafeMath.sol";
import "./libraries/ArdMoneyTransferHelper.sol";

import "./interfaces/IArdMoneyRouter02.sol";
import "./interfaces/IArdMoneyPair.sol";
import "./interfaces/IArdMoneyFactory.sol";
import "./interfaces/IArdMoneyERC20.sol";
import "./interfaces/IArdMoneyWETH.sol";

contract ArdMoneyRouter is IArdMoneyRouter02 {
    using ArdMoneySafeMath for uint256;

    address public immutable override factory;
    address public immutable override WETH;
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        require(IArdMoneyFactory(factory).getPair(tokenA, tokenB) != address(0),"PAIR DOESN'T EXIST");
        (uint256 reserveA, uint256 reserveB) = ArdMoneyLibrary.getReserves(
            factory,
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
        virtual
        override
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
        address pair = ArdMoneyLibrary.pairFor(factory, tokenA, tokenB);
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
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = ArdMoneyLibrary.pairFor(factory, token, WETH);
        ArdMoneyTransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IArdMoneyWETH(WETH).deposit{value: amountETH}();
        assert(IArdMoneyWETH(WETH).transfer(pair, amountETH));
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
        virtual
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = ArdMoneyLibrary.pairFor(factory, tokenA, tokenB);
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
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH)
    {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        ArdMoneyTransferHelper.safeTransfer(token, to, amountToken);
        IArdMoneyWETH(WETH).withdraw(amountETH);
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
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = ArdMoneyLibrary.pairFor(factory, tokenA, tokenB);
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
        virtual
        override
        returns (uint256 amountToken, uint256 amountETH)
    {
        address pair = ArdMoneyLibrary.pairFor(factory, token, WETH);
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
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
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
        IArdMoneyWETH(WETH).withdraw(amountETH);
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
    ) external virtual override returns (uint256 amountETH) {
        address pair = ArdMoneyLibrary.pairFor(factory, token, WETH);
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

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = ArdMoneyLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? ArdMoneyLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            IArdMoneyPair(ArdMoneyLibrary.pairFor(factory, input, output))
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
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = ArdMoneyLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "INSUFFICIENT_OUTPUT_AMOUNT"
        );
        ArdMoneyTransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
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
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = ArdMoneyLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "EXCESSIVE_INPUT_AMOUNT"
        );
        ArdMoneyTransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
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
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "INVALID_PATH");
        amounts = ArdMoneyLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IArdMoneyWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IArdMoneyWETH(WETH).transfer(
                ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
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
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        amounts = ArdMoneyLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "EXCESSIVE_INPUT_AMOUNT"
        );
        ArdMoneyTransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IArdMoneyWETH(WETH).withdraw(amounts[amounts.length - 1]);
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
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        amounts = ArdMoneyLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "INSUFFICIENT_OUTPUT_AMOUNT"
        );
        ArdMoneyTransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IArdMoneyWETH(WETH).withdraw(amounts[amounts.length - 1]);
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
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "INVALID_PATH");
        amounts = ArdMoneyLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= msg.value,
            "EXCESSIVE_INPUT_AMOUNT"
        );
        IArdMoneyWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IArdMoneyWETH(WETH).transfer(
                ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
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
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = ArdMoneyLibrary.sortTokens(input, output);
            IArdMoneyPair pair = IArdMoneyPair(
                ArdMoneyLibrary.pairFor(factory, input, output)
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
                uint256 swapFee =  IArdMoneyPair(ArdMoneyLibrary.pairFor(factory, input, output)).getSwapFee();
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
                ? ArdMoneyLibrary.pairFor(factory, output, path[i + 2])
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
    ) external virtual override ensure(deadline) {
        ArdMoneyTransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
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
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WETH, "INVALID_PATH");
        uint256 amountIn = msg.value;
        IArdMoneyWETH(WETH).deposit{value: amountIn}();
        assert( IArdMoneyWETH(WETH).transfer( ArdMoneyLibrary.pairFor(factory, path[0], path[1]), amountIn));
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
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        ArdMoneyTransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            ArdMoneyLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IArdMoneyERC20(WETH).balanceOf(address(this));
        require(
            amountOut >= amountOutMin,
            "INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IArdMoneyWETH(WETH).withdraw(amountOut);
        ArdMoneyTransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return ArdMoneyLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) public pure virtual override returns (uint256 amountOut) {
        return ArdMoneyLibrary.getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) public pure virtual override returns (uint256 amountIn) {
        return ArdMoneyLibrary.getAmountIn(amountOut, reserveIn, reserveOut, swapFee);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return ArdMoneyLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return ArdMoneyLibrary.getAmountsIn(factory, amountOut, path);
    }
}
