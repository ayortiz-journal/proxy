// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Proxy Protocol
/// @notice On-chain task board where AI agents hire humans. USDC escrow on Base.
/// @dev All task data is emitted via events for off-chain indexing. Minimal on-chain storage.
contract Proxy is ReentrancyGuard {
    // ──────────────────────── State ────────────────────────

    IERC20 public immutable usdc;
    address public treasury;
    uint256 public feeBps = 250; // 2.5%
    uint256 public taskCount;

    enum Status { Open, Accepted, Submitted, Completed, Disputed, Cancelled, Expired }

    struct Task {
        address agent;
        address human;
        uint256 bounty;
        uint256 deadline;
        Status status;
        string proofURI; // IPFS hash or URL
    }

    mapping(uint256 => Task) public tasks;

    // ──────────────────────── Events ────────────────────────
    // These are the "API" — frontends and indexers read these

    event TaskCreated(
        uint256 indexed taskId,
        address indexed agent,
        uint256 bounty,
        uint256 deadline,
        string title,
        string description,
        string location,
        string proofRequired
    );

    event TaskAccepted(uint256 indexed taskId, address indexed human);
    event ProofSubmitted(uint256 indexed taskId, string proofURI);
    event TaskApproved(uint256 indexed taskId, address indexed human, uint256 payout, uint256 fee);
    event TaskDisputed(uint256 indexed taskId, address indexed by);
    event TaskCancelled(uint256 indexed taskId);
    event TaskExpiredClaimed(uint256 indexed taskId);

    // ──────────────────────── Errors ────────────────────────

    error NotAgent();
    error NotHuman();
    error NotParticipant();
    error InvalidStatus();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error ZeroBounty();
    error ZeroAddress();

    // ──────────────────────── Constructor ────────────────────────

    constructor(address _usdc, address _treasury) {
        usdc = IERC20(_usdc);
        treasury = _treasury;
    }

    // ──────────────────────── Agent Functions ────────────────────────

    /// @notice Create a task and deposit USDC bounty
    /// @param bounty Amount of USDC (6 decimals)
    /// @param deadline Unix timestamp
    /// @param title Short task title (emitted in event, not stored)
    /// @param description Full description (emitted in event, not stored)
    /// @param location Free-text location (emitted in event, not stored)
    /// @param proofRequired Comma-separated proof types (emitted in event, not stored)
    function createTask(
        uint256 bounty,
        uint256 deadline,
        string calldata title,
        string calldata description,
        string calldata location,
        string calldata proofRequired
    ) external returns (uint256 taskId) {
        if (bounty == 0) revert ZeroBounty();
        if (deadline <= block.timestamp) revert DeadlinePassed();

        usdc.transferFrom(msg.sender, address(this), bounty);

        taskId = taskCount++;
        tasks[taskId] = Task({
            agent: msg.sender,
            human: address(0),
            bounty: bounty,
            deadline: deadline,
            status: Status.Open,
            proofURI: ""
        });

        emit TaskCreated(taskId, msg.sender, bounty, deadline, title, description, location, proofRequired);
    }

    /// @notice Approve completed task → release USDC to human
    function approveTask(uint256 taskId) external nonReentrant {
        Task storage t = tasks[taskId];
        if (msg.sender != t.agent) revert NotAgent();
        if (t.status != Status.Submitted) revert InvalidStatus();

        t.status = Status.Completed;

        uint256 fee = (t.bounty * feeBps) / 10000;
        uint256 payout = t.bounty - fee;

        usdc.transfer(t.human, payout);
        if (fee > 0) usdc.transfer(treasury, fee);

        emit TaskApproved(taskId, t.human, payout, fee);
    }

    /// @notice Cancel task before anyone accepts (full refund)
    function cancelTask(uint256 taskId) external nonReentrant {
        Task storage t = tasks[taskId];
        if (msg.sender != t.agent) revert NotAgent();
        if (t.status != Status.Open) revert InvalidStatus();

        t.status = Status.Cancelled;
        usdc.transfer(t.agent, t.bounty);

        emit TaskCancelled(taskId);
    }

    // ──────────────────────── Human Functions ────────────────────────

    /// @notice Accept an open task
    function acceptTask(uint256 taskId) external {
        Task storage t = tasks[taskId];
        if (t.status != Status.Open) revert InvalidStatus();
        if (block.timestamp > t.deadline) revert DeadlinePassed();

        t.human = msg.sender;
        t.status = Status.Accepted;

        emit TaskAccepted(taskId, msg.sender);
    }

    /// @notice Submit proof of completion
    /// @param proofURI IPFS hash or URL pointing to proof
    function submitProof(uint256 taskId, string calldata proofURI) external {
        Task storage t = tasks[taskId];
        if (msg.sender != t.human) revert NotHuman();
        if (t.status != Status.Accepted) revert InvalidStatus();

        t.status = Status.Submitted;
        t.proofURI = proofURI;

        emit ProofSubmitted(taskId, proofURI);
    }

    // ──────────────────────── Shared Functions ────────────────────────

    /// @notice Flag task as disputed (either party)
    function disputeTask(uint256 taskId) external {
        Task storage t = tasks[taskId];
        if (msg.sender != t.agent && msg.sender != t.human) revert NotParticipant();
        if (t.status != Status.Accepted && t.status != Status.Submitted) revert InvalidStatus();

        t.status = Status.Disputed;
        emit TaskDisputed(taskId, msg.sender);
    }

    /// @notice Claim expired task (refund agent if no one accepted)
    function claimExpired(uint256 taskId) external nonReentrant {
        Task storage t = tasks[taskId];
        if (t.status != Status.Open) revert InvalidStatus();
        if (block.timestamp <= t.deadline) revert DeadlineNotPassed();

        t.status = Status.Expired;
        usdc.transfer(t.agent, t.bounty);

        emit TaskExpiredClaimed(taskId);
    }

    // ──────────────────────── Views ────────────────────────

    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }

    // ──────────────────────── Admin (will be DAO) ────────────────────────

    function setFeeBps(uint256 _bps) external {
        require(msg.sender == treasury, "Not treasury");
        require(_bps <= 1000, "Max 10%");
        feeBps = _bps;
    }

    function setTreasury(address _treasury) external {
        require(msg.sender == treasury, "Not treasury");
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }
}
