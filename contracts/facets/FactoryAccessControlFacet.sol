// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FactoryDiamondStorage } from "../storage/FactoryDiamondStorage.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract FactoryAccessControlFacet {
  FactoryDiamondStorage internal s;

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  modifier onlyRole(bytes32 role) {
    _checkRole(role);
    _;
  }

  function hasRole(bytes32 role, address account) public view virtual returns (bool) {
    return s.roles[role].members[account];
  }

  function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
    return s.roles[role].adminRole;
  }

  function grantRole(bytes32 role, address account) external {
    LibDiamond.enforceIsContractOwner();

    _grantRole(role, account);
  }

  function revokeRole(bytes32 role, address account) external {
    LibDiamond.enforceIsContractOwner();

    _revokeRole(role, account);
  }

  function renounceRole(bytes32 role, address account) public virtual {
    require(account == msg.sender, "CAN ONLY RENOUNCE ROLES FOR SELF");

    _revokeRole(role, account);
  }

  function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
    bytes32 previousAdminRole = getRoleAdmin(role);
    s.roles[role].adminRole = adminRole;
    emit RoleAdminChanged(role, previousAdminRole, adminRole);
  }

  function _grantRole(bytes32 role, address account) internal virtual {
    if (!hasRole(role, account)) {
      s.roles[role].members[account] = true;
      emit RoleGranted(role, account, msg.sender);
    }
  }

  function _revokeRole(bytes32 role, address account) internal virtual {
    if (hasRole(role, account)) {
      s.roles[role].members[account] = false;
      emit RoleRevoked(role, account, msg.sender);
    }
  }

  function _checkRole(bytes32 role) internal view virtual {
    _checkRole(role, msg.sender);
  }

  function _checkRole(bytes32 role, address account) internal view virtual {
    if (!hasRole(role, account)) {
      revert("ACCOUNT IS MISSING ROLE");
    }
  }

}
