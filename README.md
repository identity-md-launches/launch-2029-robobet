# robobet (ROBOBET)

**Put your fate in the hands of SUPERINTELLIGENCE**  
Website: [robobet.fun](https://robobet.fun)

An immutable, fixed-supply ERC-20 token. The complete production implementation is
[`src/RobobetToken.sol`](src/RobobetToken.sol), using the vendored OpenZeppelin ERC20.

## Token and assumptions

| Property | Value |
| --- | --- |
| Solidity contract | `RobobetToken` |
| Name | `robobet` |
| Symbol | `ROBOBET` |
| Decimals | `18` |
| Supply in whole tokens | `1,000,000,000` |
| Supply in base units | `1000000000000000000000000000` (`10^27`) |
| Named supply constant | `INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18` |
| Initial recipient | Immediate constructor caller, `msg.sender` |
| Constructor arguments | None; encoded arguments are empty (`0x`) |
| Constructor value | `0` ETH |
| Admin / owner / upgrade authority | None |

The constructor mints the entire supply once and emits the standard mint
`Transfer` event. No callable mint or burn exists after deployment. All balances
and allowances use integer base units; one ROBOBET is `10^18` units.

The brief specifies token branding and a fixed supply. Its tagline and website
are descriptive metadata, not a request for an AI agent, betting system, oracle,
or external service. This project therefore contains one deployable token and no
application contracts. No tax, fee, rebasing, pause, blacklist, vesting, trading
gate, or holder seizure is implemented.

Standard transfers deliver the exact amount and return `true`; invalid operations
revert with OpenZeppelin's ERC-20 custom errors. Transfers to the zero address
and approvals to a zero spender revert. Zero-value transfers between valid
addresses succeed and emit `Transfer`. Transfers never invoke recipient code.

`approve` replaces an allowance. `transferFrom` consumes finite allowances;
`type(uint256).max` is treated as unlimited and is not decremented. An approved
spender can transfer only within the holder's balance and allowance. Failed
transfers roll back both balances and allowance changes. `approve` emits
`Approval`; this OpenZeppelin version does not emit `Approval` when
`transferFrom` spends an allowance, so integrations should query `allowance`.

## Build and test

Foundry and Solidity **0.8.26** are required. The root configuration pins that
compiler, targets Cancun, enables the optimizer with 200 runs, and sets
`bytecode_hash = "none"`. No FFI or filesystem cheatcode permissions are enabled.

```sh
forge build
FOUNDRY_FUZZ_SEED=0xb4ff2081a049c6533c797511d5002f7438465893db9981e79b09c7053e3972b6 forge test
forge fmt --check
```

Dependencies are ordinary files under `lib/`, including their licenses. No
dependency installation, submodule initialization, RPC, API credentials, or
network access is required once the pinned compiler is available. See
[`DEPENDENCIES.md`](DEPENDENCIES.md) and [`dependencies.lock.json`](dependencies.lock.json).
Tests do not read or change environment variables; the command above supplies
the requested seed to Foundry itself.

The delivered suite contains 34 tests: 29 unit/flow checks, four fuzz properties
(1,000 cases each), and one stateful supply-conservation invariant (256 sequences
of 64 actions). It checks metadata, mint destination/event, CREATE2 deployment,
exact transfers and launch distribution, approvals/revocation, infinite
allowances, zero/self transfers, invalid recipients, inadequate balances and
allowances, atomic failures, absence of privileged entry points, and runtime
size/forbidden opcodes. The invariant interleaves transfers, approvals, and
delegated transfers across four holders and accounts for every token.

The local launch fixture exercises token transfers representing distribution,
claims, and both pool directions. It does **not** simulate Uniswap pricing or
liquidity accounting. The supplied protected checks depend on the network's
separate factory, pool, manifest, and ownership harness; those integration checks
belong to the independent verifier and are not represented as locally executed.

## Deployment parameters and responsibilities

The launch target is Ethereum, chain ID `1`. Build and deploy
`src/RobobetToken.sol:RobobetToken` directly from its creation bytecode, with no
linked libraries, constructor arguments, initialization call, or proxy.
The artifact is `out/RobobetToken.sol/RobobetToken.json`.

The immediate deploying factory receives all `10^27` units. The transaction
origin, contributor, and requester receive nothing in the constructor. A direct
deployment by an EOA would instead mint to that EOA; the intended launch is the
factory deployment. The constructor makes no external calls and requires no
pre-existing contract addresses.

The launch infrastructure performs distribution and liquidity operations after
deployment. The supplied launch terms are recorded here for handoff; the token
does not implement them:

| Launch setting | Supplied value |
| --- | --- |
| Swarm distribution | 10% of total supply, through the factory's distributor |
| Pool allocation | `poolBps = 6000` (60% of total supply) |
| Remainder | 30% to `0xee2aaa315cf7ed169f93148d30d24af9318dbb66` |
| Paired currency | IMD, `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7` (18 decimals) |
| Opening market cap | `initialMarketCapWei = "5000000000000000000000"` (5,000 IMD) |
| Pool fee / tick spacing | `12500` (1.25%) / `60` |
| Price provenance field | `"79228162514264337593543950336"` |

The launch deployer derives the actual opening pool price from the supplied
market cap, supply, and token address. The pool fee is a pool setting, not a
ROBOBET transfer tax. Factory/distributor/pool addresses and exemptions are not
token parameters because every valid transfer already arrives whole. The
separate manifest step supplies `launch.json`; this project does not create one.

## After launch

There are no owner settings, service credentials, keepers, or maintenance calls.
The launch operator is responsible for the factory deployment, distribution,
liquidity setup, publishing the deployed address, and verifying the source with
the exact build settings. Post-deployment checks should confirm the name,
symbol, decimals, `10^27` total supply, and distribution transfers.

Holders control their tokens and approvals. Use bounded approvals when possible;
when replacing an existing allowance, revoke it first and wait for confirmation
before granting the replacement, accounting for any spend already made.
There is no administrator who can reverse transfers or recover tokens sent to
an inaccessible address or the token contract itself. The contract has no
payable entry point or asset-rescue function.

The implementation and vendored ERC20 paths were locally reviewed for supply
creation, allowance authorization, arithmetic bounds, and external calls.
There are no price feeds, signature authorizations, callbacks, or upgrade paths
in this token. Foundry unit tests, fuzzing, invariants, and formatting checks are
the automated checks used here; Slither and Mythril were not run. This local
review is not an independent security audit. Independent review and the
protected launch integration checks remain release responsibilities.

ERC-20 interface semantics: [EIP-20](https://eips.ethereum.org/EIPS/eip-20).

