# Stylus Zig Example Program

This PR implements the sieve of erathosthenes algorithm to compute prime numbers in Zig, to be deployed as a smart contract to [Arbitrum Stylus](https://arbitrum.io/stylus).

![Image](./sample.png)

Stylus is a new technology developed for Arbitrum chains which gives smart contract developers superpowers. With Stylus, developers can write EVM-compatible smart contracts in many different programming languages, and reap massive performance gains. Stylus slashes fees, with performance gains ranging from 10-70x, and memory efficiency gains as high as 100-500x.

## Walkthrough

See our full guide on how we added support for Zig on Arbitrum Stylus in [WALKTHROUGH.md](./WALKTHROUGH.md)

## How and Why

This is possible thanks to [WebAssembly](https://www.infoworld.com/article/3291780/what-is-webassembly-the-next-generation-web-platform-explained.html) technology, which all Stylus programs compile to. Stylus smart contracts live under the **same Ethereum state trie** in Arbitrum nodes, and can fully interoperate with Solidity or Vyper EVM smart contracts. With Stylus, developers can write smart contracts in Rust that talk to Solidity and vice versa without any limitations.

Today, the Stylus testnet also comes with 2 officially supported SDKs for developers to write contracts in the [Rust](https://github.com/OffchainLabs/stylus-sdk-rs) or [C](https://github.com/OffchainLabs/stylus-sdk-c) programming languages. 

However, _anyone_ can add support for new languages in Stylus. **As long as a programming language can compile to WebAssembly**, fit under 24Kb brotli-compressed, and meets some of the gas metering requirements of Stylus, it can be deployed and used onchain.

Why Zig?

1. Zig contains **memory safety guardrails**, requiring developers to think hard about manual memory allocation in a prudent manner
2. Zig is a **C equivalent** language, and its tooling is also a C compiler. This means C projects can incrementally adopt Zig when refactoring 
3. Zig is **lightning fast** and produces **small binaries**, making it suitable for blockchain applications

Programs written in Zig and deployed to Stylus have a tiny footprint and will have gas costs comparable, if not equal to, C programs.

## License

This project is fully open source, including an Apache-2.0 or MIT license at your choosing under your own copyright.