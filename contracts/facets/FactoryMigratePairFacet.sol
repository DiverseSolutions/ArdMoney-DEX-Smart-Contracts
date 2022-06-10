// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FactoryDiamondStorage } from "../storage/FactoryDiamondStorage.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract FactoryMigratePairFacet {
  FactoryDiamondStorage internal s;

  event PairMigrated( address indexed token0, address indexed token1, address pair, uint256);
  event PairRemoved( address pair, uint256);

  function migratePair(address token0,address token1,address newPair) external {
    require(token0 != address(0), "TOKEN0 ZERO ADDRESS");
    require(token1 != address(0), "TOKEN0 ZERO ADDRESS");
    require(s.getPair[token0][token1] == address(0), "PAIR_EXISTS");

    s.getPair[token0][token1] = newPair;
    s.getPair[token1][token0] = newPair;
    s.allPairs.push(newPair);

    emit PairMigrated(token0, token1, newPair, s.allPairs.length);
  }

  function removePair(address pair) external {
    require(pair != address(0), "ZERO ADDRESS");

    bool found = false;
    uint foundIndex = 0;

    for(uint i = 0; i < s.allPairs.length; i++){
      if(s.allPairs[i] == pair){
        found = true;
        foundIndex = i;
        break;
      }
    }

    require(found,"PAIR DOESN'T EXIST");
    require(foundIndex < s.allPairs.length, "OUT OF BOUND");

    for (uint x = foundIndex; x < s.allPairs.length - 1; x++) {
      s.allPairs[x] = s.allPairs[x + 1];
    }

    s.allPairs.pop();
    emit PairRemoved(pair, s.allPairs.length);
  }

}
