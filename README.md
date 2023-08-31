# Stylus Zig Example Program

This PR implements the sieve of erathosthenes algorithm to compute prime numbers in Zig, to be deployed as a WebAssembly smart contract to Arbitrum Stylus.

Stylus is is an upgrade to Arbitrum, an Ethereum-focused, smart contract blockchain that scales the network. In addition to supporting Ethereum smart contracts written in Solidity, Stylus supports programs written in WebAssembly. Because Zig compiles to WASM and can produce small binaries, it's an excellent fit.

Today, programs written in Zig can be deployed to the Stylus testnet, which is free to use.

## Overview

To support Stylus, your Zig programs simply need to define an entrypoint that is different from the `main` function in Zig. This entrypoint has access to reading input bytes and outputting bytes to callers of your program via two imported WebAssembly functions:

```c
pub extern "vm_hooks" fn read_args(dest: *u8) void;
pub extern "vm_hooks" fn write_result(data: *const u8, len: usize) void;
```

TODO: Cover the rest...

TODO: Explain why I had to include a custom allocator

## Building

Install Zig 0.11.0, then you can run `make all` or

```bash
zig build-lib ./src/lib.zig -target wasm32-freestanding -dynamic --export=user_entrypoint -OReleaseSmall 
```

## Deploying

## Quick Start 

Install the latest version of [Rust](https://www.rust-lang.org/tools/install), and then install the Stylus CLI tool with Cargo

```bash
cargo install cargo-stylus
```

Add the `wasm32-unknown-unknown` build target to your Rust compiler:

```
rustup target add wasm32-unknown-unknown
```

You should now have it available as a Cargo subcommand:

```bash
cargo stylus --help
```

You can then use the `cargo stylus` command to also deploy your program to the Stylus testnet. We can use the tool to first check
our program compiles to valid WASM for Stylus and will succeed a deployment onchain without transacting:

```bash
cargo stylus check --wasm-file-path=lib.wasm
```

If successful, you should see:

```bash
Finished release [optimized] target(s) in 1.88s
Compressed WASM size: 600 B
Program succeeded Stylus onchain activation checks with Stylus version: 1
```

Here's how to deploy:

```bash
cargo stylus deploy \
  --private-key=<YOUR_PRIVATE_KEY>
  --wasm-file-path=lib.wasm
```

The CLI will send 2 transactions to deploy and activate your program onchain.

```bash
Compressed WASM size: 8.9 KB
Deploying program to address 0x457b1ba688e9854bdbed2f473f7510c476a3da09
Estimated gas: 1973450
Submitting tx...
Confirmed tx 0x42db…7311, gas used 1973450
Activating program at address 0x457b1ba688e9854bdbed2f473f7510c476a3da09
Estimated gas: 14044638
Submitting tx...
Confirmed tx 0x0bdb…3307, gas used 14044638
```

Once both steps are successful, you can interact with your program as you would with any Ethereum smart contract, by making `eth_call`s to a JSON-RPC backend that supports Stylus.

TODO: Link testnet info...

## Calling Your Program

By using the program address from your deployment step above, you can attempt to call your Zig program 

```rs
let tx_req = Eip1559TransactionRequest::new()
  .to(address)
  .data(num_to_check.to_le_bytes());
let tx = TypedTransaction::Eip1559(tx_req);
let got = provider.call_raw(&tx).await?;
let end = Instant::now();
assert!(is_prime as u8 == got[0]);
```

To run it, do:

```
cd rust-example && cargo run
```

## Peeking Under the Hood

Explain what's going on...

## License

This project is fully open source, including an Apache-2.0 or MIT license at your choosing under your own copyright.