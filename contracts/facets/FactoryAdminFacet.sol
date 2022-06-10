// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FactoryDiamondStorage } from "../storage/FactoryDiamondStorage.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract FactoryAdminFacet {
  FactoryDiamondStorage internal s;

  function setFeeTo(address _feeTo) external {
    LibDiamond.enforceIsContractOwner();
    s.feeTo = _feeTo;
  }

  function setMigrator(address _migrator) external {
    LibDiamond.enforceIsContractOwner();
    s.migrator = _migrator;
  }

  function setFeeToSetter(address _feeToSetter) external {
    LibDiamond.enforceIsContractOwner();
    s.feeToSetter = _feeToSetter;
  }

}
