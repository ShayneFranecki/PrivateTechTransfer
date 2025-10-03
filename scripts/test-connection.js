const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("=== 测试部署环境 ===\n");

  try {
    // 1. 测试 RPC 连接
    console.log("1. 测试 RPC 连接...");
    const provider = ethers.provider;

    try {
      const network = await provider.getNetwork();
      console.log(`   ✅ 网络连接成功`);
      console.log(`   链 ID: ${network.chainId}`);
      console.log(`   网络名称: ${network.name}`);
    } catch (error) {
      console.log(`   ❌ 网络连接失败: ${error.message}`);
      return;
    }

    // 2. 测试账户
    console.log("\n2. 测试账户配置...");
    try {
      const [deployer] = await ethers.getSigners();
      console.log(`   ✅ 部署账户: ${deployer.address}`);

      const balance = await provider.getBalance(deployer.address);
      console.log(`   余额: ${ethers.formatEther(balance)} ETH`);

      if (balance === 0n) {
        console.log(`   ⚠️  警告: 账户余额为 0，需要测试 ETH`);
      }
    } catch (error) {
      console.log(`   ❌ 账户配置失败: ${error.message}`);
      return;
    }

    // 3. 测试区块高度
    console.log("\n3. 测试区块数据...");
    try {
      const blockNumber = await provider.getBlockNumber();
      console.log(`   ✅ 当前区块: ${blockNumber}`);
    } catch (error) {
      console.log(`   ❌ 获取区块失败: ${error.message}`);
    }

    console.log("\n=== 所有测试通过，可以尝试部署 ===\n");

  } catch (error) {
    console.error("测试失败:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
