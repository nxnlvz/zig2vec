# zig2vec

Host-side Zig emitter for a Vectrex ROM. Do not retarget the Zig compiler. `lwasm` is the assembler, not a compiler backend.

- `src/emit.zig` writes 6809 assembly to stdout.
- `build.zig` runs that program, then `lwasm --format=raw`.
- Cartridge RAM used by the ROM starts at `$C880`. The tail ring is 32 Y/X pairs at `$C8A0`.
- BIOS: `Wait_Recal` `$F192`, `Intensity_5F` `$F2A5`, `Intensity_a` `$F2AB`, `Reset0Ref` `$F354`, `Moveto_d` `$F312`, `Draw_Line_d` `$F3DF`, `Draw_VLc` `$F3CE`, `Print_Str_d` `$F37A`.
- Orbit: 8.8 fixed point. Gravity shift 10, drag shift 8, start x = 100, vy = 2. Collision is both axes inside the text.
- Tail length is `4 * min(|vx| + |vy|, 7) + 3`, clamped to samples stored. Oldest segment is dim.
