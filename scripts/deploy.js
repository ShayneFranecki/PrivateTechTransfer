const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("开始部署 PrivateTechTransfer 合约到 Sepolia 测试网...");

  // 获取平台费率（从环境变量或使用默认值）
  const platformFeeRate = process.env.PLATFORM_FEE_RATE || 100; // 默认 1% (100 基点)

  console.log(`平台费率设置为: ${platformFeeRate} 基点 (${platformFeeRate / 100}%)`);

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户地址:", deployer.address);

  // 检查账户余额
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("账户余额:", ethers.formatEther(balance), "ETH");

  // 部署合约
  const PrivateTechTransfer = await ethers.getContractFactory("PrivateTechTransfer");
  console.log("正在部署合约...");

  const privateTechTransfer = await PrivateTechTransfer.deploy(platformFeeRate);
  await privateTechTransfer.waitForDeployment();

  const contractAddress = await privateTechTransfer.getAddress();
  console.log("✅ PrivateTechTransfer 合约已部署到:", contractAddress);

  // 保存部署信息
  const deploymentInfo = {
    network: "sepolia",
    contractAddress: contractAddress,
    deployer: deployer.address,
    platformFeeRate: platformFeeRate,
    deploymentTime: new Date().toISOString(),
    blockNumber: await ethers.provider.getBlockNumber()
  };

  console.log("\n📋 部署信息:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  console.log("\n⏳ 等待几个区块确认后，可以使用以下命令验证合约:");
  console.log(`npx hardhat verify --network sepolia ${contractAddress} ${platformFeeRate}`);

  // 等待几个区块确认
  console.log("\n等待 5 个区块确认...");
  await privateTechTransfer.deploymentTransaction().wait(5);
  console.log("✅ 合约已确认");

  return deploymentInfo;
}

main()
  .then((info) => {
    console.log("\n🎉 部署成功完成！");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });
