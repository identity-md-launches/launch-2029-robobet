// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {RobobetToken} from "../src/RobobetToken.sol";

/// @dev Exercises interleaved holder operations over a closed set of accounts.
contract RobobetHandler is Test {
    uint256 internal constant SUPPLY = 1_000_000_000e18;

    RobobetToken public immutable token;
    address[4] public actors;
    // This ledger starts from the specified supply and changes only for authorized
    // operations. It never copies balances or allowances back from the token.
    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor() {
        actors[0] = makeAddr("holder 0");
        actors[1] = makeAddr("holder 1");
        actors[2] = makeAddr("holder 2");
        actors[3] = makeAddr("holder 3");
        token = new RobobetToken();
        require(token.transfer(actors[0], SUPPLY));
        expectedBalance[actors[0]] = SUPPLY;
    }

    function transfer(uint256 fromIndex, uint256 toIndex, uint256 amount) external {
        address from = actors[fromIndex % actors.length];
        address to = actors[toIndex % actors.length];
        amount = bound(amount, 0, expectedBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        _recordTransfer(from, to, amount);
    }

    function approve(uint256 ownerIndex, uint256 spenderIndex, uint256 amount) external {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        _approve(owner, spender, amount);
    }

    /// @dev Explicitly reaches revocation and the finite/unlimited approval boundary.
    function boundaryApproval(uint256 ownerIndex, uint256 spenderIndex, uint256 choice) external {
        uint256[5] memory amounts = [uint256(0), 1, SUPPLY, type(uint256).max - 1, type(uint256).max];
        _approve(actors[ownerIndex % actors.length], actors[spenderIndex % actors.length], amounts[choice % 5]);
    }

    function transferFrom(uint256 ownerIndex, uint256 spenderIndex, uint256 toIndex, uint256 amount) external {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        address to = actors[toIndex % actors.length];
        uint256 balance = expectedBalance[owner];
        uint256 allowance = expectedAllowance[owner][spender];
        amount = bound(amount, 0, balance < allowance ? balance : allowance);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        _recordTransfer(owner, to, amount);
        if (allowance != type(uint256).max) {
            expectedAllowance[owner][spender] -= amount;
        }
    }

    function rejectTransferOverBalance(uint256 fromIndex, uint256 toIndex, uint256 amount) external {
        address from = actors[fromIndex % actors.length];
        address to = actors[toIndex % actors.length];
        uint256 balance = expectedBalance[from];
        amount = bound(amount, balance + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount));
        vm.prank(from);
        token.transfer(to, amount);
    }

    function rejectTransferFromOverBalance(uint256 ownerIndex, uint256 spenderIndex, uint256 toIndex, uint256 amount)
        external
    {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        address to = actors[toIndex % actors.length];
        uint256 balance = expectedBalance[owner];
        amount = bound(amount, balance + 1, type(uint256).max);
        // A sufficient approval isolates the balance failure. The failed spend must
        // leave this approval intact, including when owner, spender and to alias.
        _approve(owner, spender, amount);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, balance, amount));
        vm.prank(spender);
        token.transferFrom(owner, to, amount);
    }

    function rejectTransferFromOverAllowance(
        uint256 ownerIndex,
        uint256 spenderIndex,
        uint256 toIndex,
        uint256 approved
    ) external {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        address to = actors[toIndex % actors.length];
        approved = bound(approved, 0, expectedBalance[owner]);
        _approve(owner, spender, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approved, approved + 1)
        );
        vm.prank(spender);
        token.transferFrom(owner, to, approved + 1);
    }

    function rejectZeroRecipient(uint256 ownerIndex, uint256 spenderIndex, uint256 amount, bool delegated) external {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        uint256 maximum = expectedBalance[owner];
        if (delegated && expectedAllowance[owner][spender] < maximum) {
            maximum = expectedAllowance[owner][spender];
        }
        amount = bound(amount, 0, maximum);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(delegated ? spender : owner);
        if (delegated) token.transferFrom(owner, address(0), amount);
        else token.transfer(address(0), amount);
    }

    function rejectZeroSpender(uint256 ownerIndex, uint256 amount) external {
        address owner = actors[ownerIndex % actors.length];
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(owner);
        token.approve(address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function _recordTransfer(address from, address to, uint256 amount) internal {
        expectedBalance[from] -= amount;
        expectedBalance[to] += amount;
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 128
/// forge-config: default.invariant.fail-on-revert = true
contract RobobetInvariantTest is Test {
    RobobetHandler internal handler;
    RobobetToken internal token;

    function setUp() public {
        handler = new RobobetHandler();
        token = handler.token();
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
        selectors[3] = handler.boundaryApproval.selector;
        selectors[4] = handler.rejectTransferOverBalance.selector;
        selectors[5] = handler.rejectTransferFromOverBalance.selector;
        selectors[6] = handler.rejectTransferFromOverAllowance.selector;
        selectors[7] = handler.rejectZeroRecipient.selector;
        selectors[8] = handler.rejectZeroSpender.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_SupplyIsFixedAndEveryUnitIsAccountedFor() public view {
        uint256 balanceSum;
        for (uint256 i; i < 4; ++i) {
            balanceSum += token.balanceOf(handler.actors(i));
        }
        assertEq(token.totalSupply(), 1_000_000_000e18);
        assertEq(balanceSum, token.totalSupply());
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
    }

    /// @dev Conservation alone cannot detect misdirected transfers or unauthorized
    /// allowance changes. Check every actor and pair, including uninvolved accounts.
    function invariant_BalancesAndAllowancesMatchAuthorizedCalls() public view {
        for (uint256 i; i < 4; ++i) {
            address owner = handler.actors(i);
            assertEq(token.balanceOf(owner), handler.expectedBalance(owner), "unauthorized balance change");
            assertEq(token.allowance(owner, address(0)), 0, "zero spender obtained an allowance");
            for (uint256 j; j < 4; ++j) {
                address spender = handler.actors(j);
                assertEq(
                    token.allowance(owner, spender),
                    handler.expectedAllowance(owner, spender),
                    "allowance differs from authorization history"
                );
            }
        }
    }
}
