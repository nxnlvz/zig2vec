# zig2vec

Host-side Zig emitter for Vectrex ROMs. Do not retarget the Zig compiler. `lwasm` is the assembler.

- `src/root.zig` is the library. It writes 6809 text. It must not contain a particular game.
- `examples/<name>/main.zig` is one cartridge. It imports the library as `zig2vec`.
- `build.zig` lists examples. Each one is compiled, its stdout is captured, and `lwasm --format=raw -o` writes `zig-out/bin/<name>.bin`. `--output` does not take a separate argument.
- A new example is a new folder under `examples/` plus one row in the `examples` array. Do not special-case it in the library.
- Cartridge RAM used by `smile` starts at `$C880`. The tail ring is 32 Y/X pairs at `$C8A0`. `$C88A` is scratch for `Asm.pull`.
- BIOS constants live in `bios` inside the library.
- `roms/hello.bin` and `roms/smile.bin` are the public cartridges for jsvecx. CI copies them from `zig-out/bin` after a successful build. Do not edit them by hand.
