// SPDX-License-Identifier: MIT

struct FactoryDiamondStorage {
  address feeTo;
  address feeToSetter;
  address migrator;

  mapping(address => mapping(address => address)) getPair;
  address[] allPairs;

  bool paused;

  mapping(bytes32 => RoleData) roles;
  bytes32 CREATE_BASIC_PAIR_ROLE;
}

struct RoleData {
  mapping(address => bool) members;
  bytes32 adminRole;
}
