// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestRCC is ERC20 {
    constructor() ERC20("TestRCC", "TRCC") {}

    function mint(address _user, uint256 _amount) external {
        _mint(_user, _amount);
    }
}