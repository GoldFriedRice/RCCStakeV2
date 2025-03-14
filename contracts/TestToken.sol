// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {}

    function mint(address _user, uint256 _amount) external {
        require(_user != address(0x0), "invalid address");
        _mint(_user, _amount);
    }
}