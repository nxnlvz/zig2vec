# zig2vec

Zig runs on the host. It prints 6809 assembly, and `lwasm` turns that into a Vectrex cartridge. The 6809 does not run Zig.

The ROM draws `HELLO WORLD` and a smiley on a shrinking elliptical orbit. Each frame the cartridge integrates a central pull (`position >> 10`) and drag (`velocity >> 8`). A tail follows the samples the face has already visited. Faster movement keeps a longer tail. At about ten seconds the face meets the text, the string changes to `GOODBYE WORLD`, and the tail collapses.

## Build

Zig 0.14 and `lwasm` (from lwtools) on `PATH`.

```sh
zig build
```

- `zig-out/game.s` is the generated assembly
- `zig-out/bin/game.bin` is the cartridge

Load the bin in a Vectrex emulator.
