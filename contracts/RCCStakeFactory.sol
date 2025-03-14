// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRCCStakeFactory.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract RCCStakeFactory is AccessControlUpgradeable, IRCCStakeFactory {
    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    mapping (address => address) pools;

    function initialize() public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function addPool(address _stTokenAddress, address _pool) external onlyRole(ADMIN_ROLE) {
        require(_pool != address(0x0), "invalid pool address");
        pools[_stTokenAddress] = _pool;
    }

    function getPool(address stTokenAddress) external view returns (address pool) {
        return pools[stTokenAddress];
    }
}