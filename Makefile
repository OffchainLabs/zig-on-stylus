all:
	zig build-lib ./src/main.zig -target wasm32-freestanding -dynamic --export=user_entrypoint -OReleaseSmall 