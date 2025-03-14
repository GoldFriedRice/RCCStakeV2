// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRCCStakePool {
    function stakingBalance(address _user) external returns (uint256);
    function pendingWithdraw(address _user) external returns (uint256);
    function pendingReward(address _user) external returns (uint256);
    function stakeNativeCurrency(address _user) external payable;
    function stakeToken(address _user, uint256 _amount) external;
    function unstake(address _user, uint256 _amount) external;
    function withdraw(address _user) external;
    function claim(address _user) external;
}