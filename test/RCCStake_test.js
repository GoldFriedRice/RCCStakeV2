
const { ethers, artifacts } = require("hardhat");
const { expect } = require("chai");

async function mineBlocks(numBlocks) {
    for (let i = 0; i < numBlocks; i++) {
        await network.provider.send("evm_mine");
    }
}

describe("RCCStake test", () => {
    let testRCCStake;
    let testRcc;
    let testToken;
    let testAccount;
    let ethPoolAddress = ethers.ZeroAddress;
    let tokenContactAddress;

    const ethRewardPerBlock = 10;
    const tokenRewardPerBlock = 1;

    beforeEach(async () => {
        const [owner, testAcc1, testAcc2] = await ethers.getSigners();
        testRcc = await ethers.deployContract("TestRCC");
        await testRcc.waitForDeployment();
        testToken = await ethers.deployContract("TestToken");
        await testToken.waitForDeployment();
        await testToken.mint(await testAcc1.getAddress(), ethers.parseEther("100"));

        testFactory = await ethers.deployContract("RCCStakeFactory");
        await testFactory.waitForDeployment();
        await testFactory.initialize();

        const blockNumber = await ethers.provider.getBlockNumber();
        const startBlock = blockNumber;
        const endBlock = blockNumber + 1000000;

        ethPool = await ethers.deployContract("RCCStakePool");
        await ethPool.waitForDeployment();
        await ethPool.initialize(await testRcc.getAddress(), ethPoolAddress, startBlock, endBlock, ethRewardPerBlock);
        await testFactory.addPool(ethPoolAddress, await ethPool.getAddress());
        await testRcc.mint(await ethPool.getAddress(), ethers.parseEther("100"));

        tokenPool = await ethers.deployContract("RCCStakePool");
        await tokenPool.waitForDeployment();
        await tokenPool.initialize(await testRcc.getAddress(), await testToken.getAddress(), startBlock, endBlock, tokenRewardPerBlock);
        await testFactory.addPool(await testToken.getAddress(), await tokenPool.getAddress());
        await testRcc.mint(await tokenPool.getAddress(), ethers.parseEther("100"));

        testRCCStake = await ethers.deployContract("RCCStakeV2");
        await testRCCStake.waitForDeployment();
        await testRCCStake.initialize(await testFactory.getAddress());
        
        testAccount = testAcc1;
        tokenContactAddress = await testToken.getAddress();
    });

    it("eth stake", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(ethPoolAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        await expect(testRCCStake.connect(testAccount).stake(ethPoolAddress, testAccount.address, 0, {value: amount})).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);
        expect(await ethers.provider.getBalance(poolAddress)).to.equal(amount);
    });

    it("token stake", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(tokenContactAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        const tokenABI = (await artifacts.readArtifact("TestToken")).abi;
        const tokenContract = await ethers.getContractAt(tokenABI, tokenContactAddress);
        await tokenContract.connect(testAccount).approve(poolAddress, amount);

        const allowance = await tokenContract.allowance(testAccount.address, poolAddress);
        expect(allowance).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).stake(tokenContactAddress, testAccount.address, amount)).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);
    });

    it("eth unstake", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(ethPoolAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        await expect(testRCCStake.connect(testAccount).stake(ethPoolAddress, testAccount.address, 0, {value: amount})).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);
        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);
        expect(await ethers.provider.getBalance(poolAddress)).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).unstake(ethPoolAddress, testAccount.address, amount)).to.emit(poolContract, "Unstake").withArgs(testAccount.address, amount);
        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(0);
        expect(await poolContract.pendingWithdraw(testAccount.address)).to.equal(amount);
    });

    it("token unstake", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(tokenContactAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        const tokenABI = (await artifacts.readArtifact("TestToken")).abi;
        const tokenContract = await ethers.getContractAt(tokenABI, tokenContactAddress);
        await tokenContract.connect(testAccount).approve(poolAddress, amount);

        const allowance = await tokenContract.allowance(testAccount.address, poolAddress);
        expect(allowance).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).stake(tokenContactAddress, testAccount.address, amount)).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).unstake(tokenContactAddress, testAccount.address, amount)).to.emit(poolContract, "Unstake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(0);
        expect(await poolContract.pendingWithdraw(testAccount.address)).to.equal(amount);
    });

    it("eth withdraw", async () => {
        const amount = ethers.parseEther("1");

        const stakeTx = await testRCCStake.connect(testAccount).stake(ethPoolAddress, testAccount.address, 0, {value: amount});
        await stakeTx.wait();

        const poolAddress = await testRCCStake.getPool(ethPoolAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);
        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);
        expect(await ethers.provider.getBalance(poolAddress)).to.equal(amount);

        const unstakeTx = await testRCCStake.connect(testAccount).unstake(ethPoolAddress, testAccount.address, amount);
        await unstakeTx.wait();
        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(0);
        expect(await poolContract.pendingWithdraw(testAccount.address)).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).withdraw(ethPoolAddress, testAccount.address)).to.emit(poolContract, "Withdraw").withArgs(testAccount.address, amount);

        expect(await poolContract.pendingWithdraw(testAccount.address)).to.equal(0);
        expect(afterBalance - beforeBalance).to.equal(amount);
    });

    it("token withdraw", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(tokenContactAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        const tokenABI = (await artifacts.readArtifact("TestToken")).abi;
        const tokenContract = await ethers.getContractAt(tokenABI, tokenContactAddress);
        await tokenContract.connect(testAccount).approve(poolAddress, amount);

        const allowance = await tokenContract.allowance(testAccount.address, poolAddress);
        expect(allowance).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).stake(tokenContactAddress, testAccount.address, amount)).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).unstake(tokenContactAddress, testAccount.address, amount)).to.emit(poolContract, "Unstake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(0);
        expect(await poolContract.pendingWithdraw(testAccount.address)).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).withdraw(tokenContactAddress, testAccount.address)).to.emit(poolContract, "Withdraw").withArgs(testAccount.address, amount);
        expect(await poolContract.pendingWithdraw(testAccount.address)).to.equal(0);
    });

    it("eth claim", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(ethPoolAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        await expect(testRCCStake.connect(testAccount).stake(ethPoolAddress, testAccount.address, 0, {value: amount})).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);

        expect(await poolContract.stakingBalance(testAccount.address)).to.equal(amount);
        expect(await ethers.provider.getBalance(poolAddress)).to.equal(amount);

        const durationBlocks = 100;
        await mineBlocks(durationBlocks);

        await expect(testRCCStake.connect(testAccount).claim(ethPoolAddress, testAccount.address)).to.emit(poolContract, "Claim").withArgs(testAccount.address, durationBlocks * ethRewardPerBlock);
        expect(await testRcc.balanceOf(testAccount.address)).to.equal(durationBlocks * ethRewardPerBlock);
    });

    it("token claim", async () => {
        const amount = ethers.parseEther("1");

        const poolAddress = await testRCCStake.getPool(tokenContactAddress);
        const poolABI = (await artifacts.readArtifact("RCCStakePool")).abi;
        const poolContract = await ethers.getContractAt(poolABI, poolAddress);

        const tokenABI = (await artifacts.readArtifact("TestToken")).abi;
        const tokenContract = await ethers.getContractAt(tokenABI, tokenContactAddress);
        await tokenContract.connect(testAccount).approve(poolAddress, amount);

        const allowance = await tokenContract.allowance(testAccount.address, poolAddress);
        expect(allowance).to.equal(amount);

        await expect(testRCCStake.connect(testAccount).stake(tokenContactAddress, testAccount.address, amount)).to.emit(poolContract, "Stake").withArgs(testAccount.address, amount);

        const durationBlocks = 100;
        await mineBlocks(durationBlocks);

        await expect(testRCCStake.connect(testAccount).claim(tokenContactAddress, testAccount.address)).to.emit(poolContract, "Claim").withArgs(testAccount.address, durationBlocks * tokenRewardPerBlock);
        expect(await testRcc.balanceOf(testAccount.address)).to.equal(durationBlocks * tokenRewardPerBlock);
    });
});