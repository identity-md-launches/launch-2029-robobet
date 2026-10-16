// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {RobobetToken} from "../src/RobobetToken.sol";

contract RobobetTokenTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;

    RobobetToken internal token;
    address internal deployer;
    address internal alice;
    address internal bob;
    address internal spender;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        spender = makeAddr("spender");
        vm.prank(deployer);
        token = new RobobetToken();
    }

    function test_MetadataAndEntireInitialSupply() public view {
        assertEq(token.name(), "robobet");
        assertEq(token.symbol(), "ROBOBET");
        assertEq(token.decimals(), 18);
        assertEq(token.INITIAL_SUPPLY(), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.allowance(deployer, spender), 0);
    }

    function test_ConstructorEmitsMintEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), deployer, SUPPLY);
        vm.prank(deployer);
        new RobobetToken();
    }

    function test_TransferEmitsEventAndDeliversExactAmount() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(deployer, alice, 25e18);
        vm.prank(deployer);
        assertTrue(token.transfer(alice, 25e18));
        assertEq(token.balanceOf(deployer), SUPPLY - 25e18);
        assertEq(token.balanceOf(alice), 25e18);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_WholeSupplyCanMoveAndReturn() public {
        vm.prank(deployer);
        assertTrue(token.transfer(alice, SUPPLY));
        assertEq(token.balanceOf(deployer), 0);
        vm.prank(alice);
        assertTrue(token.transfer(deployer, SUPPLY));
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_ZeroTransferFromEmptyAccountEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_SelfTransferPreservesBalance() public {
        vm.prank(deployer);
        assertTrue(token.transfer(deployer, SUPPLY));
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_RevertWhenTransferExceedsBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, SUPPLY + 1)
        );
        vm.prank(deployer);
        token.transfer(alice, SUPPLY + 1);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_RevertWhenEmptyAccountTransfersOneUnit() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function test_RevertWhenSelfTransferExceedsBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, SUPPLY + 1)
        );
        vm.prank(deployer);
        token.transfer(deployer, SUPPLY + 1);
    }

    function test_RevertWhenTransferToZeroAddressIncludingZeroAmount() public {
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
        vm.stopPrank();
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ApproveEmitsEventAndReplacesAllowance() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(deployer, spender, 20e18);
        assertTrue(token.approve(spender, 20e18));
        assertEq(token.allowance(deployer, spender), 20e18);
        assertTrue(token.approve(spender, 5e18));
        assertEq(token.allowance(deployer, spender), 5e18);
        vm.stopPrank();
        assertEq(token.balanceOf(deployer), SUPPLY);
    }

    function test_ApprovalDoesNotRequireBalance() public {
        vm.prank(alice);
        assertTrue(token.approve(spender, SUPPLY));
        assertEq(token.allowance(alice, spender), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_RevertWhenApproveZeroSpender() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(deployer);
        token.approve(address(0), 1);
        assertEq(token.allowance(deployer, address(0)), 0);
    }

    function test_TransferFromEmitsEventAndConsumesAllowance() public {
        vm.prank(deployer);
        token.approve(spender, 100e18);

        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(deployer, alice, 40e18);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 40e18));
        assertEq(token.allowance(deployer, spender), 60e18);
        assertEq(token.balanceOf(deployer), SUPPLY - 40e18);
        assertEq(token.balanceOf(alice), 40e18);

        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, bob, 60e18));
        assertEq(token.allowance(deployer, spender), 0);
        assertEq(token.balanceOf(bob), 60e18);
    }

    function test_InfiniteAllowanceIsNotDecremented() public {
        vm.prank(deployer);
        token.approve(spender, type(uint256).max);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 50e18));
        assertEq(token.allowance(deployer, spender), type(uint256).max);
        assertEq(token.balanceOf(alice), 50e18);
    }

    function test_RevocationStopsPreviouslyApprovedSpender() public {
        vm.startPrank(deployer);
        token.approve(spender, type(uint256).max);
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(deployer, spender, 0);
        token.approve(spender, 0);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(deployer, alice, 1);
        assertEq(token.balanceOf(deployer), SUPPLY);
    }

    function test_RevertWhenSpenderExceedsAllowanceWithoutChangingState() public {
        vm.prank(deployer);
        token.approve(spender, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 10, 11));
        vm.prank(spender);
        token.transferFrom(deployer, alice, 11);
        assertEq(token.allowance(deployer, spender), 10);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_RevertWhenDifferentSpenderUsesApproval() public {
        vm.prank(deployer);
        token.approve(spender, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 10));
        vm.prank(bob);
        token.transferFrom(deployer, alice, 10);
        assertEq(token.allowance(deployer, spender), 10);
        assertEq(token.balanceOf(deployer), SUPPLY);
    }

    function test_TransferFromInsufficientBalanceRollsBackAllowance() public {
        vm.prank(alice);
        token.approve(spender, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 10));
        vm.prank(spender);
        token.transferFrom(alice, bob, 10);
        assertEq(token.allowance(alice, spender), 10);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_TransferFromInvalidRecipientRollsBackAllowance() public {
        vm.prank(deployer);
        token.approve(spender, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(deployer, address(0), 10);
        assertEq(token.allowance(deployer, spender), 10);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ZeroTransferFromWithoutAllowanceEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.allowance(alice, spender), 0);
    }

    function test_RevertWhenTransferFromZeroSenderEvenForZeroAmount() public {
        // OpenZeppelin checks the allowance owner before reaching the balance transfer.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(0), alice, 0);
    }

    function test_SelfTransferFromPreservesBalanceButConsumesAllowance() public {
        vm.prank(deployer);
        token.approve(spender, 7);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, deployer, 7));
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.allowance(deployer, spender), 0);
    }

    function test_DeployerCannotMoveHolderTokensWithoutApproval() public {
        vm.prank(deployer);
        token.transfer(alice, 10e18);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, deployer, 0, 1));
        vm.prank(deployer);
        token.transferFrom(alice, deployer, 1);
        assertEq(token.balanceOf(alice), 10e18);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 10e18));
    }

    function test_NoMintBurnPauseSeizureOrUpgradeEntryPoints() public {
        vm.prank(deployer);
        token.transfer(alice, 10e18);
        bytes[15] memory calls = [
            abi.encodeWithSignature("mint(address,uint256)", bob, 1),
            abi.encodeWithSignature("mint(uint256)", 1),
            abi.encodeWithSignature("mint()"),
            abi.encodeWithSignature("burn(uint256)", 1),
            abi.encodeWithSignature("burnFrom(address,uint256)", alice, 1),
            abi.encodeWithSignature("pause()"),
            abi.encodeWithSignature("blacklist(address)", alice),
            abi.encodeWithSignature("freeze(address)", alice),
            abi.encodeWithSignature("seize(address)", alice),
            abi.encodeWithSignature("setTransfersEnabled(bool)", false),
            abi.encodeWithSignature("transferOwnership(address)", bob),
            abi.encodeWithSignature("upgradeTo(address)", bob),
            abi.encodeWithSignature("initialize(address)", bob),
            abi.encodeWithSignature("setMinter(address)", bob),
            abi.encodeWithSignature("owner()")
        ];
        for (uint256 i; i < calls.length; ++i) {
            vm.prank(deployer);
            (bool deployerSucceeded,) = address(token).call(calls[i]);
            assertFalse(deployerSucceeded, "deployer reached an unexpected entry point");
            vm.prank(bob);
            (bool strangerSucceeded,) = address(token).call(calls[i]);
            assertFalse(strangerSucceeded, "stranger reached an unexpected entry point");
        }
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(alice), 10e18);
        assertEq(token.balanceOf(bob), 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 10e18));
    }

    function test_RuntimeFitsDeploymentLimitAndHasNoDangerousOpcodes() public view {
        bytes memory runtime = address(token).code;
        assertGt(runtime.length, 0);
        assertLe(runtime.length, 24_576);
        for (uint256 i; i < runtime.length; ++i) {
            uint8 op = uint8(runtime[i]);
            if (op >= 0x60 && op <= 0x7f) {
                i += op - 0x5f;
            } else {
                assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
            }
        }
    }

    function testFuzz_TransferConservesSupply(address recipient, uint256 amount) public {
        vm.assume(recipient != address(0) && recipient != deployer);
        amount = bound(amount, 0, SUPPLY);
        vm.prank(deployer);
        assertTrue(token.transfer(recipient, amount));
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(deployer), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_TransferFromUsesExactlyTheApprovedAmount(uint256 approved, uint256 spent) public {
        approved = bound(approved, 0, SUPPLY);
        spent = bound(spent, 0, approved);
        vm.prank(deployer);
        token.approve(spender, approved);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, spent));
        assertEq(token.balanceOf(alice), spent);
        assertEq(token.balanceOf(deployer), SUPPLY - spent);
        assertEq(token.allowance(deployer, spender), approved - spent);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_ExcessiveTransferRevertsAtomically(uint256 amount) public {
        amount = bound(amount, SUPPLY + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, amount)
        );
        vm.prank(deployer);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_ExcessiveDelegatedTransferRevertsAtomically(uint256 approved) public {
        approved = bound(approved, 0, SUPPLY - 1);
        vm.prank(deployer);
        token.approve(spender, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approved, approved + 1)
        );
        vm.prank(spender);
        token.transferFrom(deployer, alice, approved + 1);
        assertEq(token.allowance(deployer, spender), approved);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }
}
