// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRCCStakePool.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RCCStakePool is 
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    IRCCStakePool {

    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    IERC20 RCC;
    address stTokenAddress;
    uint256 rewardRCCPerBlock;
    uint256 minStakeAmount;
    uint256 unstakeLockedBlocks;

    uint256 startBlock;
    uint256 endBlock;

    bool withdrawPaused;
    bool claimPaused;

    struct UnstakeRequest {
        uint256 amount;
        uint256 unlockBlock;
    }

    struct User {
        uint256 stAmount;
        uint256 finishedRCC;
        uint256 pendingRCC;
        UnstakeRequest[] requests;
        uint256 lastRewardBlock;
    }

    mapping(address => User) public users;

    event SetRCC(IERC20 indexed RCC);
    event PauseWithdraw();
    event UnpauseWithdraw();
    event PauseClaim();
    event UnpauseClaim();
    event SetStartBlock(uint256 indexed startBlock);
    event SetEndBlock(uint256 indexed endBlock);
    event SetRewardRCCPerBlock(uint256 indexed rewardRCCPerBlock);
    event Update(uint256 indexed minStakeAmount, uint256 indexed unstakeLockedBlocks);
    event Stake(address indexed user, uint256 indexed amount);
    event Unstake(address indexed user, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed amount);
    event Claim(address indexed user, uint256 indexed amount);

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    function initialize(IERC20 _RCC, address _stTokenAddress, uint256 _startBlock, uint256 _endBlock, uint256 _rewardRCCPerBlock) public initializer {
        require(_startBlock < _endBlock && _rewardRCCPerBlock > 0, "invalid parameters");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setRCC(_RCC);

        stTokenAddress = _stTokenAddress;
        startBlock = _startBlock;
        endBlock = _endBlock;
        rewardRCCPerBlock = _rewardRCCPerBlock;
    }

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override{}

    // ************************************** ADMIN FUNCTION **************************************
    function setRCC(IERC20 _RCC) public onlyRole(ADMIN_ROLE) {
        RCC = _RCC;
        emit SetRCC(RCC);
    }

    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");
        withdrawPaused = true;
        emit PauseWithdraw();
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");
        withdrawPaused = false;
        emit UnpauseWithdraw();
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");
        claimPaused = true;
        emit PauseClaim();
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");
        claimPaused = false;
        emit UnpauseClaim();
    }

    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock < endBlock, "start block must be smaller than end block");
        startBlock = _startBlock;
        emit SetStartBlock(_startBlock);
    }

    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(_endBlock > startBlock, "start block must be smaller than end block");
        endBlock = _endBlock;
        emit SetEndBlock(_endBlock);
    }

    function setRewardRCCPerBlock(uint256 _rewardRCCPerBlock) public onlyRole(ADMIN_ROLE) {
        rewardRCCPerBlock = _rewardRCCPerBlock;
        emit SetRewardRCCPerBlock(_rewardRCCPerBlock);
    }
    
    function update(uint256 _minStakeAmount, uint256 _unstakeLockedBlocks) external onlyRole(ADMIN_ROLE) {
        minStakeAmount = _minStakeAmount;
        unstakeLockedBlocks = _unstakeLockedBlocks;
        emit Update(_minStakeAmount, _unstakeLockedBlocks);
    }

    // ************************************** QUERY FUNCTION **************************************
    function stakingBalance(address _user) external view returns (uint256) {
        return users[_user].stAmount;
    }

    function pendingWithdraw(address _user) external view returns (uint256) {
        User storage user = users[_user];
        uint256 pendingWithdrawAmount;
        for (uint256 i = 0; i < user.requests.length; i++) {
            if (user.requests[i].unlockBlock > block.number) {
                break;
            }
            pendingWithdrawAmount += user.requests[i].amount;
        }
        return pendingWithdrawAmount;
    }

    function pendingReward(address _user) external returns (uint256) {
        User storage user = users[_user];
        require(block.number > startBlock, "not started");
        _updateUserReward(_user);
        return user.pendingRCC;
    }

    function stakeNativeCurrency(address _user) external whenNotPaused() payable {
        require(stTokenAddress == address(0x0), "invalid staking token address");
        require(block.number > startBlock, "not start yet");
        uint256 value = msg.value;
        require(value > minStakeAmount, "stake amount is too small");
        _stake(_user, value);
    }

    function stakeToken(address _user, uint256 _amount) external whenNotPaused() {
        require(stTokenAddress != address(0x0), "invalid staking token address");
        require(block.number > startBlock, "not start yet");
        require(_amount > minStakeAmount, "stake amount is too small");
        if (_amount > 0) {
            IERC20(stTokenAddress).safeTransferFrom(_user, address(this), _amount);
        }
        _stake(_user, _amount);
    }

    function unstake(address _user, uint256 _amount) external whenNotPaused(){
        require(block.number < endBlock, "already ended");
        User storage user = users[_user];
        require(_amount <= user.stAmount, "Not enough staking token balance");
        _updateUserReward(_user);
        if (_amount > 0) {
            user.stAmount -= _amount;
            user.requests.push(UnstakeRequest({
                amount: _amount,
                unlockBlock: block.number + unstakeLockedBlocks
            }));
        }
        emit Unstake(_user, _amount);
    }

    function withdraw(address _user) external whenNotPaused() whenNotWithdrawPaused() {
        User storage user = users[_user];
        uint256 pendingWithdrawAmount;
        uint256 pops;
        for (uint256 i = 0; i < user.requests.length; i++) {
            if (user.requests[i].unlockBlock > block.number) {
                break;
            }
            pendingWithdrawAmount += user.requests[i].amount;
            pops++;
        }
        for (uint256 i = 0; i < user.requests.length - pops; i++) {
            user.requests[i] = user.requests[i + pops];
        }
        for (uint256 i = 0; i < pops; i++) {
            user.requests.pop();
        }
        if (pendingWithdrawAmount > 0) {
            if (stTokenAddress == address(0x0)) {
                _safeNativeCurrencyWithdraw(msg.sender, pendingWithdrawAmount);
            } else {
                IERC20(stTokenAddress).safeTransfer(msg.sender, pendingWithdrawAmount);
            }
        }
        emit Withdraw(_user, pendingWithdrawAmount);
    }
    
    function claim(address _user) external whenNotPaused() whenNotClaimPaused() {
        _updateUserReward(_user);
        User storage user = users[_user];
        uint256 pendingRCC = user.pendingRCC;
        if (pendingRCC > 0) {
            user.pendingRCC = 0;
            _safeRCCTransfer(_user, pendingRCC);
        }
        user.finishedRCC += pendingRCC;
        emit Claim(_user, pendingRCC);
    }

    // ************************************** INTERNAL FUNCTION **************************************
    function _updateUserReward(address _user) internal {
        User storage user = users[_user];
        require(user.stAmount > 0, "user did not stake");
        if (block.number > user.lastRewardBlock) {
            uint256 pendingRCC = user.stAmount / (1 ether) * (block.number - user.lastRewardBlock - 1) * rewardRCCPerBlock;
            user.pendingRCC += pendingRCC;
        }
        user.lastRewardBlock = block.number;
    }

    function _stake(address _user, uint256 _amount) internal {
        User storage user = users[_user];
    	if (user.stAmount > 0 && block.number > user.lastRewardBlock) {
            _updateUserReward(_user);
        }							
        if (_amount > 0) {
            user.stAmount += _amount;
        }
        user.lastRewardBlock = block.number;
        emit Stake(_user, _amount);
    }

    function _safeNativeCurrencyWithdraw(address _to, uint256 _amount) internal {
        require(address(this).balance >= _amount, "Insufficient contract balance");
        require(_to != address(0x0), "receiver should not be the zero address");
        (bool success, bytes memory data) = payable(_to).call{value: _amount}("");

        require(success, "nativeCurrency transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "nativeCurrency transfer operation did not succeed"
            );
        }
    }
    
    function _safeRCCTransfer(address _to, uint256 _amount) internal {
        uint256 RCCBalance = RCC.balanceOf(address(this));
        if (_amount > RCCBalance) {
            RCC.transfer(_to, RCCBalance);
        } else {
            RCC.transfer(_to, _amount);
        }
    }
}