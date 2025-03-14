// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRCCStakeFactory.sol";
import "./interfaces/IRCCStakePool.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract RCCStakeV2 is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable {

    event SetFactory(address indexed factory);

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    IRCCStakeFactory public factory;
    
    function initialize(address _factory) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        require(_factory != address(0x0), "invalid parameters");
        factory = IRCCStakeFactory(_factory);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override{}

    // ************************************** ADMIN FUNCTION **************************************
    function setFactory(address _factory) public onlyRole(ADMIN_ROLE) {
        require(_factory != address(0x0), "invalid factory address");
        factory = IRCCStakeFactory(_factory);
        emit SetFactory(_factory);
    }

    // ************************************** QUERY FUNCTION **************************************
    function getPool(address _stTokenAddress) public view returns (address) {
        address poolAddress = factory.getPool(_stTokenAddress);
        require(poolAddress != address(0x0), "pool not exsit");
        return poolAddress;
    }

    function stakingBalance(address _stTokenAddress, address _user) public returns (uint256) {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        return pool.stakingBalance(_user);
    }

    function pendingWithdraw(address _stTokenAddress, address _user) public returns (uint256) {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        return pool.pendingWithdraw(_user);
    }

    function pendingReward(address _stTokenAddress, address _user) public returns (uint256) {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        return pool.pendingReward(_user);
    }

    function stake(address _stTokenAddress, address _user, uint256 _amount) public payable {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        if (_stTokenAddress == address(0x0)) {
            pool.stakeNativeCurrency{value: msg.value}(_user);
        } else {
            pool.stakeToken(_user, _amount);
        }
    }

    function unstake(address _stTokenAddress, address _user, uint256 _amount) public {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        pool.unstake(_user, _amount);
    }

    function withdraw(address _stTokenAddress, address _user) public {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        pool.withdraw(_user);
    }

    function claim(address _stTokenAddress, address _user) public {
        IRCCStakePool pool = IRCCStakePool(getPool(_stTokenAddress));
        pool.claim(_user);
    }
}