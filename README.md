# Stylus Zig Example Program


This PR implements the sieve of erathosthenes algorithm to compute prime numbers in Zig, to be deployed as a WebAssembly smart contract to Arbitrum Stylus.

Stylus

## Building

Tested on Zig 0.11.0

```bash
zig build-lib ./src/lib.zig -target wasm32-freestanding -dynamic --export=user_entrypoint -OReleaseSmall 
```

## Deploying
