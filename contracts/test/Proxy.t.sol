// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000 * 1e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract ProxyTest is Test {
    Proxy public proxy;
    MockUSDC public usdc;

    address agent = makeAddr("agent");
    address human = makeAddr("human");
    address treasury = makeAddr("treasury");

    function setUp() public {
        usdc = new MockUSDC();
        proxy = new Proxy(address(usdc), treasury);

        // Fund agent
        usdc.mint(agent, 10_000 * 1e6);
        vm.prank(agent);
        usdc.approve(address(proxy), type(uint256).max);
    }

    function test_fullLifecycle() public {
        // Agent creates task
        vm.prank(agent);
        uint256 taskId = proxy.createTask(
            25 * 1e6,                             // 25 USDC
            block.timestamp + 1 days,             // deadline
            "Pick up dry cleaning",
            "Go to 456 Oak Ave, pick up order #7823",
            "San Francisco, CA",
            "photo,receipt"
        );

        assertEq(taskId, 0);
        assertEq(usdc.balanceOf(address(proxy)), 25 * 1e6);

        // Human accepts
        vm.prank(human);
        proxy.acceptTask(taskId);

        (,address h,,,,) = proxy.tasks(taskId);
        assertEq(h, human);

        // Human submits proof
        vm.prank(human);
        proxy.submitProof(taskId, "ipfs://QmXyz123");

        // Agent approves
        vm.prank(agent);
        proxy.approveTask(taskId);

        // Human got paid (minus 2.5% fee)
        uint256 fee = (25 * 1e6 * 250) / 10000;
        assertEq(usdc.balanceOf(human), 25 * 1e6 - fee);
        assertEq(usdc.balanceOf(treasury), fee);
    }

    function test_cancelBeforeAcceptance() public {
        vm.prank(agent);
        uint256 taskId = proxy.createTask(10 * 1e6, block.timestamp + 1 days, "Test", "", "", "");

        uint256 balBefore = usdc.balanceOf(agent);
        vm.prank(agent);
        proxy.cancelTask(taskId);

        assertEq(usdc.balanceOf(agent), balBefore + 10 * 1e6);
    }

    function test_expiredRefund() public {
        vm.prank(agent);
        uint256 taskId = proxy.createTask(10 * 1e6, block.timestamp + 1 hours, "Test", "", "", "");

        vm.warp(block.timestamp + 2 hours);

        uint256 balBefore = usdc.balanceOf(agent);
        proxy.claimExpired(taskId);
        assertEq(usdc.balanceOf(agent), balBefore + 10 * 1e6);
    }

    function test_revertAcceptAfterDeadline() public {
        vm.prank(agent);
        uint256 taskId = proxy.createTask(10 * 1e6, block.timestamp + 1 hours, "Test", "", "", "");

        vm.warp(block.timestamp + 2 hours);

        vm.prank(human);
        vm.expectRevert(Proxy.DeadlinePassed.selector);
        proxy.acceptTask(taskId);
    }

    function test_revertApproveWithoutProof() public {
        vm.prank(agent);
        uint256 taskId = proxy.createTask(10 * 1e6, block.timestamp + 1 days, "Test", "", "", "");

        vm.prank(human);
        proxy.acceptTask(taskId);

        vm.prank(agent);
        vm.expectRevert(Proxy.InvalidStatus.selector);
        proxy.approveTask(taskId);
    }

    function test_dispute() public {
        vm.prank(agent);
        uint256 taskId = proxy.createTask(10 * 1e6, block.timestamp + 1 days, "Test", "", "", "");

        vm.prank(human);
        proxy.acceptTask(taskId);

        vm.prank(human);
        proxy.disputeTask(taskId);

        (,,,,Proxy.Status status,) = proxy.tasks(taskId);
        assertEq(uint8(status), uint8(Proxy.Status.Disputed));
    }
}
