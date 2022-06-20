// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

interface IArdMoneyFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event PairMigrated( address indexed token0, address indexed token1, address pair, uint256);
    event PairRemoved( address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);

    function paused() external view returns (bool);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, uint swapFee, uint protocolFee, address admin) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
    function pause() external;
    function unPause() external;
    function migratePair(address token0,address token1,address newPair) external;
    function removePair(address pair) external;
}
