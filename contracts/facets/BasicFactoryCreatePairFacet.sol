// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import { FactoryDiamondStorage } from "../storage/FactoryDiamondStorage.sol";
import "../ArdMoneyPair.sol";

contract BasicFactoryCreatePairFacet {
  FactoryDiamondStorage internal s;
  event PairCreated( address indexed token0, address indexed token1, address pair, uint256);

  function createPair(address tokenA, address tokenB, uint swapFee, uint protocolFee, address admin)
  external
  returns (address pair){
    require(s.paused == false,"FACTORY PAUSED");
    require(s.roles[keccak256("CREATE_BASIC_PAIR_ROLE")].members[msg.sender] == true,"NO ACCESS");

    require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
    (address token0, address token1) = tokenA < tokenB
      ? (tokenA, tokenB)
      : (tokenB, tokenA);
      require(token0 != address(0), "ZERO_ADDRESS");
      require(
        s.getPair[token0][token1] == address(0),
        "PAIR_EXISTS"
      ); // single check is sufficient
      bytes memory bytecode = type(ArdMoneyPair).creationCode;
      bytes32 salt = keccak256(abi.encodePacked(token0, token1));
      assembly {
        pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
      }
      ArdMoneyPair(pair).initialize(token0, token1, swapFee, protocolFee, admin);
      s.getPair[token0][token1] = pair;
      s.getPair[token1][token0] = pair; // populate mapping in the reverse direction
      s.allPairs.push(pair);

      emit PairCreated(token0, token1, pair, s.allPairs.length);
  }
}
