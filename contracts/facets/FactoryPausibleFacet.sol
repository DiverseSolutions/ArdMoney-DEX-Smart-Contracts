// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FactoryDiamondStorage } from "../storage/FactoryDiamondStorage.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract FactoryPausibleFacet {
  FactoryDiamondStorage internal s;

  event Paused(address account);
  event Unpaused(address account);

  function paused() external view returns (bool) {
    return s.paused;
  }

  function pause() external {
    require(s.paused == false,"ALREADY PAUSED");
    LibDiamond.enforceIsContractOwner();

    s.paused = true;
    emit Paused(msg.sender);
  }

  function unPause() external {
    require(s.paused == true,"NOT PAUSED");
    LibDiamond.enforceIsContractOwner();

    s.paused = false;
    emit Unpaused(msg.sender);
  }

}
