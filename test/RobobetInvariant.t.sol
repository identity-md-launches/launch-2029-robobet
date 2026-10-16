// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {RobobetToken} from "../src/RobobetToken.sol";

/// @dev Exercises interleaved holder operations over a closed set of accounts.
contract RobobetHandler is Test {
    RobobetToken public immutable token;
    address[4] public actors;

    constructor() {
        actors[0] = makeAddr("holder 0");
        actors[1] = makeAddr("holder 1");
        actors[2] = makeAddr("holder 2");
        actors[3] = makeAddr("holder 3");
        token = new RobobetToken();
        require(token.transfer(actors[0], token.totalSupply()));
    }

    function transfer(uint256 fromIndex, uint256 toIndex, uint256 amount) external {
        address from = actors[fromIndex % actors.length];
        address to = actors[toIndex % actors.length];
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
    }

    function approve(uint256 ownerIndex, uint256 spenderIndex, uint256 amount) external {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
    }

    function transferFrom(uint256 ownerIndex, uint256 spenderIndex, uint256 toIndex, uint256 amount) external {
        address owner = actors[ownerIndex % actors.length];
        address spender = actors[spenderIndex % actors.length];
        address to = actors[toIndex % actors.length];
        uint256 balance = token.balanceOf(owner);
        uint256 allowance = token.allowance(owner, spender);
        amount = bound(amount, 0, balance < allowance ? balance : allowance);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
    }
}

contract RobobetInvariantTest is Test {
    RobobetHandler internal handler;
    RobobetToken internal token;

    function setUp() public {
        handler = new RobobetHandler();
        token = handler.token();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
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
}
