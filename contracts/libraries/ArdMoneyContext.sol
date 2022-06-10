// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

contract ArdMoneyContext {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
