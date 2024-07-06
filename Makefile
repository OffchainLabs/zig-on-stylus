all:
	zig build-exe ./src/main.zig -target wasm32-freestanding --export=user_entrypoint -fno-entry -OReleaseSmall 