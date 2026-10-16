# Vendored dependencies

All dependencies are checked in as ordinary source files, not submodules. They
are pinned to the following upstream commits and are unchanged from those
commits. Builds resolve only these local files using `remappings.txt`.

| Dependency | Release | Commit | Included files |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/dbb6104ce834628e473d2173bbc9d47f81a9eec3) | v5.0.2 | `dbb6104ce834628e473d2173bbc9d47f81a9eec3` | ERC20 and its four transitive Solidity dependencies, plus MIT license |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std/tree/77041d2ce690e692d6e03cc812b57d1ddaa4d505) | v1.9.7 | `77041d2ce690e692d6e03cc812b57d1ddaa4d505` | Solidity `src/` files and Apache-2.0 / MIT licenses; test dependency only |

[`dependencies.lock.json`](dependencies.lock.json) records each source repository,
release, commit, archive URL, and the SHA-256 digest of every included file. No
download is part of the build. Original notices and licenses are retained in
each dependency directory.

The OpenZeppelin subset is limited to `ERC20.sol`, `IERC20.sol`,
`IERC20Metadata.sol`, `Context.sol`, and `draft-IERC6093.sol`. It is used without
extensions or overridden transfer/approval logic. Forge Standard Library is
only imported from `test/` and is absent from deployed token bytecode.
