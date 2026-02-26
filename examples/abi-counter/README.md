# ABI-Compatible Counter Contract

A Stylus smart contract example that demonstrates **proper Solidity ABI encoding** in Zig. Unlike the basic prime-checker which uses raw bytes, this contract uses standard 4-byte function selectors and ABI-encoded `uint256` parameters.

## Features

- **Comptime function selectors**: keccak256 selectors computed at compile time (zero runtime cost)
- **Standard ABI compatibility**: Works with ethers.js, viem, cast, and any Ethereum tooling
- **Persistent storage**: Counter value stored in contract storage slot 0
- **Tiny binary**: ~2.8KB WASM (well under Stylus 24KB limit)

## Interface

```solidity
// Equivalent Solidity interface
interface ICounter {
    function getCount() external view returns (uint256);
    function increment() external;
    function decrement() external;
    function setCount(uint256 value) external;
    function add(uint256 value) external;
}
```

## Build

```bash
cd examples/abi-counter
zig build
# Output: zig-out/bin/abi-counter.wasm
```

## Interact

After deploying to a Stylus-enabled chain:

```bash
# Read counter
cast call <contract_address> "getCount()(uint256)"

# Increment
cast send <contract_address> "increment()" --private-key <key>

# Set to specific value
cast send <contract_address> "setCount(uint256)" 42 --private-key <key>
```

## How It Works

The contract dispatches on the first 4 bytes of calldata (the function selector):

```zig
const SEL_INCREMENT = comptimeSelector("increment()");
// SEL_INCREMENT is computed at compile time via keccak256
// and embedded as a constant in the WASM binary
```

Function parameters are ABI-encoded as big-endian `uint256` values (32 bytes), matching the standard Ethereum ABI specification.
