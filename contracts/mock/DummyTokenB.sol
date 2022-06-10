// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./DiverseERC20.sol";

contract DummyTokenB is DiverseERC20 {
    constructor() DiverseERC20("DummyToken-B", "TKN-B") public {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

