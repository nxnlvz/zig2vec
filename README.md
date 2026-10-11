# zig2vec

Zig runs on the host. It prints 6809 assembly, and `lwasm` turns that into a Vectrex cartridge. The 6809 does not run Zig. There is no 6809 backend. A game is a Zig function that appends assembly text.

## Layout

```text
src/root.zig            library: assembly writer, BIOS addresses, cartridge header
examples/hello/         static "HELLO WORLD" cartridge
examples/smile/         orbiting smiley with a velocity-scaled tail
build.zig               one ROM step per example
.github/workflows/      GitHub Actions build
```

`src/` does not know about a particular game. An example imports it as `zig2vec` and fills an `Asm` buffer. `build.zig` compiles that example, captures stdout, and runs:

```text
lwasm --format=raw --output <name>.bin <name>.s
```

## Library

`Asm` owns no memory. The caller passes a buffer. The methods used by games are `line`, `fmt`, `label`, `jsr`, `ldx`, `text`, `pairs`, `asrD`, and `pull`.

`bios` holds the stock ROM entry points (`Wait_Recal` `$F192`, `Print_Str_d` `$F37A`, `Draw_VLc` `$F3CE`, `Draw_Line_d` `$F3DF`, and the rest). `header` writes the `g GCE` cartridge header. `writeStdout` is what `main` calls so `zig build` can capture the assembly.

`pull` emits `vel = vel - (pos >> shift)` and uses `$C88A` as scratch. Games that call it should not reuse that word for something else during the shift.

## Examples

### hello

`examples/hello` clears the frame with `Wait_Recal` and prints `HELLO WORLD`. It is the smallest cartridge that uses the library.

### smile

`examples/smile` is the game. Each frame the 6809 integrates an 8.8 fixed-point orbit:

- position and velocity live at `$C880`
- gravity is `position >> 10`, which is a central pull proportional to distance, so the path is an ellipse
- drag is `velocity >> 8`, so the ellipse shrinks
- start position x = 100, velocity y = 2
- at about ten seconds both axes are inside the text, the string changes from `HELLO WORLD` to `GOODBYE WORLD`, and integration stops

The tail is a 32-sample ring at `$C8A0`. Length is `4 * min(|vx| + |vy|, 7) + 3`, clamped to the samples stored. A fast pass keeps a longer arc. The oldest segment is drawn at intensity `$08` and each newer segment is brighter, so the far end fades. After the collision, velocity is cleared and the tail collapses.

## Build locally

You need Zig 0.14 and `lwasm` on `PATH`. Ubuntu 24.04 does not package lwtools, so build it:

```sh
curl -fsSL -o lwtools.tar.gz https://www.lwtools.ca/releases/lwtools/lwtools-4.25.tar.gz
tar -xzf lwtools.tar.gz
make -C lwtools-4.25
sudo make -C lwtools-4.25 install

zig build
```

Outputs:

| File | What it is |
|---|---|
| `zig-out/hello.s` | assembly for the hello cartridge |
| `zig-out/bin/hello.bin` | hello ROM |
| `zig-out/smile.s` | assembly for the smile cartridge |
| `zig-out/bin/smile.bin` | smile ROM |

Load a `.bin` in a Vectrex emulator (Vecx, or the Vectrex tab in MAME). The file is a raw cartridge image, not an ELF.

## Add an example

1. Create `examples/<name>/main.zig`.
2. `@import("zig2vec")`, fill an `Asm`, and write it with `writeStdout` from `main`.
3. Add a row to the `examples` array in `build.zig`.

`zig build` then emits `zig-out/bin/<name>.bin` with no other changes. The GitHub Actions workflow uploads every `zig-out/bin/*.bin`, so the new ROM is included on the next run.

## GitHub Actions

`.github/workflows/build.yml` is the **Build ROMs** workflow. It runs when:

- a commit is pushed to `main`
- a pull request is opened or updated
- you start it by hand with **Run workflow**

The job is on `ubuntu-latest`. It downloads Zig 0.14.1 from ziglang.org, builds lwtools 4.25 (Ubuntu does not package it), runs `zig build`, and uploads `zig-out/bin/*.bin` plus the `.s` files as the `vectrex-roms` artifact.

To download a ROM:

1. Open the repository on GitHub and choose the **Actions** tab.
2. Choose **Build ROMs**. A push to `main` starts a run on its own. Otherwise choose **Run workflow**.
3. Open the finished run. The green job has an **Artifacts** section. Download `vectrex-roms`. The zip contains `hello.bin` and `smile.bin`.

If the Actions tab says workflows are disabled, go to **Settings → Actions → General** and allow actions. A repository owned by a user account usually runs them as soon as the workflow file is on `main`. The first run is the commit that added this file.
