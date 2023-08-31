all:
	zig build-lib ./src/lib.zig -target wasm32-freestanding -dynamic --export=user_entrypoint -OReleaseSmall 