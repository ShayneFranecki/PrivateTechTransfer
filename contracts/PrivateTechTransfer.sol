// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, euint64, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract PrivateTechTransfer is SepoliaConfig {

    address public platformOwner;
    uint256 public platformFeeRate; // 以基点为单位 (1% = 100 基点)
    uint256 public totalTechCount;

    // 技术成果状态
    enum TechStatus {
        Submitted,     // 已提交
        UnderReview,   // 评审中
        Approved,      // 已批准
        Listed,        // 已上架
        InNegotiation, // 谈判中
        Transferred,   // 已转让
        Rejected       // 已拒绝
    }

    // 机密技术成果信息
    struct TechAsset {
        uint256 id;
        address owner;
        euint64 encryptedPrice;        // 加密价格
        euint32 encryptedValuation;    // 加密估值
        string publicDescription;      // 公开描述
        bytes32 confidentialHash;      // 机密信息哈希
        TechStatus status;
        uint256 submissionTime;
        uint256 approvalTime;
        bool isExclusive;              // 是否独占转让
        address[] interestedBuyers;    // 感兴趣的买方列表
    }

    // 转让提案
    struct TransferProposal {
        uint256 techId;
        address buyer;
        euint64 encryptedOfferPrice;   // 加密报价
        string terms;                  // 转让条款
        uint256 proposalTime;
        bool isAccepted;
        bool isRejected;
        bytes32 confidentialTermsHash; // 机密条款哈希
    }

    // 评估报告
    struct EvaluationReport {
        uint256 techId;
        address evaluator;
        euint32 encryptedScore;        // 加密评分
        bytes32 reportHash;            // 报告哈希
        uint256 evaluationTime;
        bool isConfidential;
    }

    mapping(uint256 => TechAsset) public techAssets;
    mapping(uint256 => TransferProposal[]) public techProposals;
    mapping(uint256 => EvaluationReport[]) public evaluationReports;
    mapping(address => bool) public authorizedEvaluators;
    mapping(address => uint256[]) public ownerTechAssets;
    mapping(address => uint256[]) public buyerInterests;

    event TechAssetSubmitted(uint256 indexed techId, address indexed owner, uint256 timestamp);
    event TechAssetApproved(uint256 indexed techId, address indexed approver, uint256 timestamp);
    event TechAssetListed(uint256 indexed techId, address indexed owner);
    event TransferProposalSubmitted(uint256 indexed techId, address indexed buyer, uint256 proposalIndex);
    event TechAssetTransferred(uint256 indexed techId, address indexed from, address indexed to, uint256 timestamp);
    event EvaluationReportSubmitted(uint256 indexed techId, address indexed evaluator);
    event BuyerInterestRegistered(uint256 indexed techId, address indexed buyer);
    event ConfidentialDataAccessed(uint256 indexed techId, address indexed accessor, uint256 timestamp);

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can perform this action");
        _;
    }

    modifier onlyTechOwner(uint256 _techId) {
        require(techAssets[_techId].owner == msg.sender, "Only tech asset owner can perform this action");
        _;
    }

    modifier onlyAuthorizedEvaluator() {
        require(authorizedEvaluators[msg.sender], "Only authorized evaluators can perform this action");
        _;
    }

    modifier validTechAsset(uint256 _techId) {
        require(_techId > 0 && _techId <= totalTechCount, "Invalid tech asset ID");
        _;
    }

    constructor(uint256 _platformFeeRate) {
        platformOwner = msg.sender;
        platformFeeRate = _platformFeeRate;
        totalTechCount = 0;
    }

    // 提交技术成果
    function submitTechAsset(
        uint64 _price,
        uint32 _valuation,
        string memory _publicDescription,
        bytes32 _confidentialHash,
        bool _isExclusive
    ) external {
        totalTechCount++;

        // 加密价格和估值
        euint64 encryptedPrice = FHE.asEuint64(_price);
        euint32 encryptedValuation = FHE.asEuint32(_valuation);

        techAssets[totalTechCount] = TechAsset({
            id: totalTechCount,
            owner: msg.sender,
            encryptedPrice: encryptedPrice,
            encryptedValuation: encryptedValuation,
            publicDescription: _publicDescription,
            confidentialHash: _confidentialHash,
            status: TechStatus.Submitted,
            submissionTime: block.timestamp,
            approvalTime: 0,
            isExclusive: _isExclusive,
            interestedBuyers: new address[](0)
        });

        ownerTechAssets[msg.sender].push(totalTechCount);

        // 设置FHE权限
        FHE.allowThis(encryptedPrice);
        FHE.allowThis(encryptedValuation);
        FHE.allow(encryptedPrice, msg.sender);
        FHE.allow(encryptedValuation, msg.sender);

        emit TechAssetSubmitted(totalTechCount, msg.sender, block.timestamp);
    }

    // 平台方审批技术成果
    function approveTechAsset(uint256 _techId) external onlyPlatformOwner validTechAsset(_techId) {
        require(techAssets[_techId].status == TechStatus.Submitted ||
                techAssets[_techId].status == TechStatus.UnderReview,
                "Tech asset not in reviewable status");

        techAssets[_techId].status = TechStatus.Approved;
        techAssets[_techId].approvalTime = block.timestamp;

        emit TechAssetApproved(_techId, msg.sender, block.timestamp);
    }

    // 技术拥有者上架技术成果
    function listTechAsset(uint256 _techId) external onlyTechOwner(_techId) validTechAsset(_techId) {
        require(techAssets[_techId].status == TechStatus.Approved, "Tech asset must be approved first");

        techAssets[_techId].status = TechStatus.Listed;

        emit TechAssetListed(_techId, msg.sender);
    }

    // 注册购买意向
    function registerBuyerInterest(uint256 _techId) external validTechAsset(_techId) {
        require(techAssets[_techId].status == TechStatus.Listed, "Tech asset not available for interest");
        require(techAssets[_techId].owner != msg.sender, "Cannot register interest in own tech asset");

        // 检查是否已经注册过兴趣
        bool alreadyInterested = false;
        for (uint i = 0; i < techAssets[_techId].interestedBuyers.length; i++) {
            if (techAssets[_techId].interestedBuyers[i] == msg.sender) {
                alreadyInterested = true;
                break;
            }
        }

        require(!alreadyInterested, "Already registered interest");

        techAssets[_techId].interestedBuyers.push(msg.sender);
        buyerInterests[msg.sender].push(_techId);

        emit BuyerInterestRegistered(_techId, msg.sender);
    }

    // 提交转让提案
    function submitTransferProposal(
        uint256 _techId,
        uint64 _offerPrice,
        string memory _terms,
        bytes32 _confidentialTermsHash
    ) external validTechAsset(_techId) {
        require(techAssets[_techId].status == TechStatus.Listed, "Tech asset not available for proposals");
        require(techAssets[_techId].owner != msg.sender, "Cannot propose to own tech asset");

        euint64 encryptedOfferPrice = FHE.asEuint64(_offerPrice);

        TransferProposal memory newProposal = TransferProposal({
            techId: _techId,
            buyer: msg.sender,
            encryptedOfferPrice: encryptedOfferPrice,
            terms: _terms,
            proposalTime: block.timestamp,
            isAccepted: false,
            isRejected: false,
            confidentialTermsHash: _confidentialTermsHash
        });

        techProposals[_techId].push(newProposal);

        // 更新技术状态为谈判中
        if (techAssets[_techId].status == TechStatus.Listed) {
            techAssets[_techId].status = TechStatus.InNegotiation;
        }

        // 设置FHE权限
        FHE.allowThis(encryptedOfferPrice);
        FHE.allow(encryptedOfferPrice, msg.sender);
        FHE.allow(encryptedOfferPrice, techAssets[_techId].owner);

        emit TransferProposalSubmitted(_techId, msg.sender, techProposals[_techId].length - 1);
    }

    // 接受转让提案
    function acceptTransferProposal(uint256 _techId, uint256 _proposalIndex)
        external onlyTechOwner(_techId) validTechAsset(_techId) {
        require(_proposalIndex < techProposals[_techId].length, "Invalid proposal index");
        require(!techProposals[_techId][_proposalIndex].isAccepted, "Proposal already accepted");
        require(!techProposals[_techId][_proposalIndex].isRejected, "Proposal already rejected");

        TransferProposal storage proposal = techProposals[_techId][_proposalIndex];
        proposal.isAccepted = true;

        // 转移技术成果所有权
        address previousOwner = techAssets[_techId].owner;
        techAssets[_techId].owner = proposal.buyer;
        techAssets[_techId].status = TechStatus.Transferred;

        // 更新所有权记录
        _removeFromOwnerAssets(previousOwner, _techId);
        ownerTechAssets[proposal.buyer].push(_techId);

        emit TechAssetTransferred(_techId, previousOwner, proposal.buyer, block.timestamp);
    }

    // 提交评估报告
    function submitEvaluationReport(
        uint256 _techId,
        uint32 _score,
        bytes32 _reportHash,
        bool _isConfidential
    ) external onlyAuthorizedEvaluator validTechAsset(_techId) {
        euint32 encryptedScore = FHE.asEuint32(_score);

        EvaluationReport memory newReport = EvaluationReport({
            techId: _techId,
            evaluator: msg.sender,
            encryptedScore: encryptedScore,
            reportHash: _reportHash,
            evaluationTime: block.timestamp,
            isConfidential: _isConfidential
        });

        evaluationReports[_techId].push(newReport);

        // 设置FHE权限
        FHE.allowThis(encryptedScore);
        if (!_isConfidential) {
            FHE.allow(encryptedScore, techAssets[_techId].owner);
        }

        emit EvaluationReportSubmitted(_techId, msg.sender);
    }

    // 比较两个加密价格（仅限授权用户）
    function compareEncryptedPrices(uint256 _techId1, uint256 _techId2)
        external validTechAsset(_techId1) validTechAsset(_techId2)
        returns (ebool) {
        require(techAssets[_techId1].owner == msg.sender ||
                techAssets[_techId2].owner == msg.sender ||
                msg.sender == platformOwner,
                "Not authorized to compare prices");

        return FHE.gt(techAssets[_techId1].encryptedPrice, techAssets[_techId2].encryptedPrice);
    }

    // 授权评估师
    function authorizeEvaluator(address _evaluator) external onlyPlatformOwner {
        authorizedEvaluators[_evaluator] = true;
    }

    // 撤销评估师授权
    function revokeEvaluatorAuthorization(address _evaluator) external onlyPlatformOwner {
        authorizedEvaluators[_evaluator] = false;
    }

    // 更新平台费率
    function updatePlatformFeeRate(uint256 _newFeeRate) external onlyPlatformOwner {
        require(_newFeeRate <= 1000, "Fee rate cannot exceed 10%"); // 最大10%
        platformFeeRate = _newFeeRate;
    }

    // 获取技术成果基本信息
    function getTechAssetInfo(uint256 _techId) external view validTechAsset(_techId)
        returns (
            uint256 id,
            address owner,
            string memory publicDescription,
            TechStatus status,
            uint256 submissionTime,
            bool isExclusive,
            uint256 interestedBuyerCount
        ) {
        TechAsset storage tech = techAssets[_techId];
        return (
            tech.id,
            tech.owner,
            tech.publicDescription,
            tech.status,
            tech.submissionTime,
            tech.isExclusive,
            tech.interestedBuyers.length
        );
    }

    // 获取用户拥有的技术成果列表
    function getOwnerTechAssets(address _owner) external view returns (uint256[] memory) {
        return ownerTechAssets[_owner];
    }

    // 获取用户感兴趣的技术成果列表
    function getBuyerInterests(address _buyer) external view returns (uint256[] memory) {
        return buyerInterests[_buyer];
    }

    // 获取技术成果的提案数量
    function getTechProposalCount(uint256 _techId) external view validTechAsset(_techId) returns (uint256) {
        return techProposals[_techId].length;
    }

    // 获取技术成果的评估报告数量
    function getTechEvaluationCount(uint256 _techId) external view validTechAsset(_techId) returns (uint256) {
        return evaluationReports[_techId].length;
    }

    // 内部函数：从拥有者资产列表中移除
    function _removeFromOwnerAssets(address _owner, uint256 _techId) internal {
        uint256[] storage assets = ownerTechAssets[_owner];
        for (uint i = 0; i < assets.length; i++) {
            if (assets[i] == _techId) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                break;
            }
        }
    }

    // 记录机密数据访问
    function recordConfidentialAccess(uint256 _techId) external validTechAsset(_techId) {
        require(techAssets[_techId].owner == msg.sender ||
                authorizedEvaluators[msg.sender] ||
                msg.sender == platformOwner,
                "Not authorized to access confidential data");

        emit ConfidentialDataAccessed(_techId, msg.sender, block.timestamp);
    }
}