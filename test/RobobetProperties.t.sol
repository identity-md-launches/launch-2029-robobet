// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {RobobetToken} from "src/RobobetToken.sol";

/// @dev Complements the existing examples with arithmetic boundaries, interacting
/// approvals, and properties relating equivalent sequences of public calls.
/// forge-config: default.fuzz.runs = 1000
contract RobobetPropertiesTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000e18;

    RobobetToken internal token;
    address internal deployer;
    address internal alice;
    address internal bob;
    address internal spender;

    function setUp() public {
        deployer = makeAddr("properties deployer");
        alice = makeAddr("properties alice");
        bob = makeAddr("properties bob");
        spender = makeAddr("properties spender");
        vm.prank(deployer);
        token = new RobobetToken();
    }

    function test_OneBelowMaximumAllowanceIsFinite() public {
        vm.prank(deployer);
        assertTrue(token.approve(spender, type(uint256).max - 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 1));
        assertEq(token.allowance(deployer, spender), type(uint256).max - 2);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(deployer), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_MaximumTransferCannotOverflowBalances() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, type(uint256).max)
        );
        vm.prank(deployer);
        token.transfer(alice, type(uint256).max);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_MaximumDelegatedTransferCannotBypassBalanceWithInfiniteAllowance() public {
        vm.prank(deployer);
        token.approve(spender, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, type(uint256).max)
        );
        vm.prank(spender);
        token.transferFrom(deployer, alice, type(uint256).max);
        assertEq(token.allowance(deployer, spender), type(uint256).max);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_MaximumFiniteApprovalSurvivesFailedSpend() public {
        uint256 approved = type(uint256).max - 1;
        vm.prank(deployer);
        token.approve(spender, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, approved)
        );
        vm.prank(spender);
        token.transferFrom(deployer, alice, approved);
        assertEq(token.allowance(deployer, spender), approved);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_HolderUsingTransferFromNeedsItsOwnApproval() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, deployer, 0, 1));
        vm.prank(deployer);
        token.transferFrom(deployer, alice, 1);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);

        vm.startPrank(deployer);
        assertTrue(token.approve(deployer, SUPPLY));
        assertTrue(token.transferFrom(deployer, alice, SUPPLY));
        vm.stopPrank();
        assertEq(token.balanceOf(deployer), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.allowance(deployer, deployer), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_OverlappingApprovalsCannotOverspendHolderOrEachOther() public {
        vm.prank(deployer);
        token.transfer(alice, 10);
        vm.startPrank(alice);
        token.approve(spender, 6);
        token.approve(bob, 7);
        vm.stopPrank();

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, spender, 6));
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.allowance(alice, bob), 7);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 4, 7));
        vm.prank(bob);
        token.transferFrom(alice, bob, 7);
        assertEq(token.allowance(alice, bob), 7);
        assertEq(token.balanceOf(alice), 4);
        assertEq(token.balanceOf(bob), 0);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 4));
        assertEq(token.allowance(alice, bob), 3);
        assertEq(token.balanceOf(bob), 4);
        assertEq(token.balanceOf(spender), 6);
        assertEq(token.balanceOf(alice), 0);

        // Refunding the holder does not replenish a spender's exhausted allowance.
        vm.prank(deployer);
        token.transfer(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, spender, 1);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(spender), 6);
        assertEq(token.allowance(alice, bob), 3);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ZeroApprovalStillRejectsZeroSpender() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(deployer);
        token.approve(address(0), 0);
        assertEq(token.allowance(deployer, address(0)), 0);
        assertEq(token.balanceOf(deployer), SUPPLY);
    }

    function testFuzz_FiniteAllowanceRetainsAllUnspentBits(uint256 approved, uint256 spent) public {
        approved = bound(approved, 1, type(uint256).max - 1);
        spent = bound(spent, 1, approved < SUPPLY ? approved : SUPPLY);
        vm.prank(deployer);
        assertTrue(token.approve(spender, approved));
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, spent));
        assertEq(token.allowance(deployer, spender), approved - spent);
        assertEq(token.balanceOf(alice), spent);
        assertEq(token.balanceOf(deployer), SUPPLY - spent);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_FundedHolderBalanceFailureIsAtomic(uint256 funded, uint256 amount, bool infinite) public {
        funded = bound(funded, 0, SUPPLY);
        amount = bound(amount, funded + 1, type(uint256).max);
        uint256 approved = infinite ? type(uint256).max : amount;
        vm.prank(deployer);
        token.transfer(alice, funded);
        vm.prank(alice);
        token.approve(spender, approved);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, funded, amount));
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), approved);
        assertEq(token.balanceOf(alice), funded);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(deployer), SUPPLY - funded);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_InvalidRecipientPreservesAnyAllowance(uint256 approved, uint256 amount) public {
        amount = bound(amount, 0, approved < SUPPLY ? approved : SUPPLY);
        vm.prank(deployer);
        token.approve(spender, approved);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(deployer, address(0), amount);
        assertEq(token.allowance(deployer, spender), approved);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_ReplacementApprovalCanBeSpentAndRevoked(uint256 previous, uint256 replacement, uint256 spent)
        public
    {
        spent = bound(spent, 0, replacement < SUPPLY ? replacement : SUPPLY);
        vm.startPrank(deployer);
        assertTrue(token.approve(spender, previous));
        assertTrue(token.approve(spender, replacement));
        vm.stopPrank();
        assertEq(token.allowance(deployer, spender), replacement);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, spent));
        assertEq(
            token.allowance(deployer, spender), replacement == type(uint256).max ? replacement : replacement - spent
        );
        vm.prank(deployer);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(deployer, alice, 1);
        assertEq(token.allowance(deployer, spender), 0);
        assertEq(token.balanceOf(deployer), SUPPLY - spent);
        assertEq(token.balanceOf(alice), spent);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_SplitTransfersMatchOneTransfer(uint256 first, uint256 second) public {
        first = bound(first, 0, SUPPLY);
        second = bound(second, 0, SUPPLY - first);
        vm.prank(deployer);
        RobobetToken singleTransfer = new RobobetToken();

        vm.startPrank(deployer);
        assertTrue(token.transfer(alice, first));
        assertTrue(token.transfer(alice, second));
        assertTrue(singleTransfer.transfer(alice, first + second));
        vm.stopPrank();
        assertEq(token.balanceOf(alice), first + second);
        assertEq(token.balanceOf(alice), singleTransfer.balanceOf(alice));
        assertEq(token.balanceOf(deployer), singleTransfer.balanceOf(deployer));
        assertEq(token.balanceOf(deployer) + token.balanceOf(alice), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(singleTransfer.totalSupply(), SUPPLY);
    }

    function testFuzz_DelegatedRoundTripRestoresBalancesAndExhaustsBudget(uint256 amount, uint256 first) public {
        amount = bound(amount, 1, SUPPLY);
        first = bound(first, 0, amount);
        vm.prank(deployer);
        token.approve(spender, amount);
        vm.startPrank(spender);
        assertTrue(token.transferFrom(deployer, alice, first));
        assertTrue(token.transferFrom(deployer, alice, amount - first));
        vm.stopPrank();
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), SUPPLY - amount);
        assertEq(token.allowance(deployer, spender), 0);

        vm.prank(alice);
        assertTrue(token.transfer(deployer, amount));
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(deployer, spender), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(deployer, bob, 1);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
