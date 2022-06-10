// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "../ArdMoneyPair.sol";

import { FactoryDiamondStorage } from "../storage/FactoryDiamondStorage.sol";

contract FactoryUtilityFacet {
  FactoryDiamondStorage internal s;
  event PairCreated( address indexed token0, address indexed token1, address pair, uint256);

  function allPairs(uint index) view external returns (address) {
    return s.allPairs[index];
  }

  function allPairsLength() external view returns (uint256) {
    return s.allPairs.length;
  }

  function getPair(address token0,address token1) external view returns (address) {
    return s.getPair[token0][token1];
  }

  function feeTo() view external returns (address) {
    return s.feeTo;
  }

  function feeToSetter() view external returns (address) {
    return s.feeToSetter;
  }

  function migrator() view external returns (address) {
    return s.migrator;
  }

  function pairCodeHash() external pure returns (bytes32) {
    return keccak256(type(ArdMoneyPair).creationCode);
  }

}
