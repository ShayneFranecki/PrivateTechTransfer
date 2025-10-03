const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("开始部署 PrivateTechTransfer 合约到 Sepolia 测试网...\n");

  // 获取平台费率
  const platformFeeRate = process.env.PLATFORM_FEE_RATE || 100;
  console.log(`平台费率: ${platformFeeRate} 基点 (${platformFeeRate / 100}%)`);

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);

  // 检查余额
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("账户余额:", ethers.formatEther(balance), "ETH\n");

  if (balance === 0n) {
    console.log("❌ 错误: 账户余额为 0，请先获取 Sepolia 测试 ETH");
    console.log("水龙头: https://sepoliafaucet.com");
    process.exit(1);
  }

  // 获取合约工厂
  console.log("正在准备部署...");
  const PrivateTechTransfer = await ethers.getContractFactory("PrivateTechTransfer");

  // 部署合约（不等待确认）
  console.log("发送部署交易...");
  const privateTechTransfer = await PrivateTechTransfer.deploy(platformFeeRate);

  console.log("交易已发送！");
  console.log("交易哈希:", privateTechTransfer.deploymentTransaction().hash);

  // 等待部署交易被打包（只等待1个确认）
  console.log("\n等待交易被打包...");
  await privateTechTransfer.waitForDeployment();

  const contractAddress = await privateTechTransfer.getAddress();
  console.log("\n🎉 合约部署成功！");
  console.log("=" .repeat(60));
  console.log("合约地址:", contractAddress);
  console.log("部署者:", deployer.address);
  console.log("平台费率:", platformFeeRate, "基点");
  console.log("交易哈希:", privateTechTransfer.deploymentTransaction().hash);
  console.log("=" .repeat(60));

  // 保存部署信息到文件
  const fs = require('fs');
  const deploymentInfo = {
    network: "sepolia",
    contractAddress: contractAddress,
    deployer: deployer.address,
    platformFeeRate: platformFeeRate,
    txHash: privateTechTransfer.deploymentTransaction().hash,
    deploymentTime: new Date().toISOString(),
    blockNumber: await ethers.provider.getBlockNumber()
  };

  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\n部署信息已保存到: deployment-info.json");

  console.log("\n验证合约命令:");
  console.log(`npx hardhat verify --network sepolia ${contractAddress} ${platformFeeRate}`);

  console.log("\n在 Etherscan 查看:");
  console.log(`https://sepolia.etherscan.io/address/${contractAddress}`);
}

main()
  .then(() => {
    console.log("\n✅ 部署完成！");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 部署失败:", error.message);
    if (error.error) {
      console.error("详细错误:", error.error);
    }
    process.exit(1);
  });
