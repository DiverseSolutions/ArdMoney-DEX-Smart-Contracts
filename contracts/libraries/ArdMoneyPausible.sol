// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity =0.6.12;

contract ArdMoneyPausible {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor() public {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "ArdMoney: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "ArdMoney: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}
