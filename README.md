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
lwasm --format=raw -o <name>.bin <name>.s
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

Load a `.bin` in a Vectrex emulator. The file is a raw cartridge image, not an ELF. On a Mac, `zig build` opens it for you. See below.

## Mac

A local `zig build` on macOS builds every ROM, then opens `smile.bin` in RetroArch and waits. Quit RetroArch and the build command returns. GitHub Actions is Linux and does not launch anything.

### Requirements

| Tool | Why | How |
|---|---|---|
| Xcode Command Line Tools | `make` and `clang`, used to build `lwasm` | `xcode-select --install` |
| Zig **0.14.1** | Host compiler. 0.15 and later will not build this tree (`std.posix`) | Tarball below. `brew install zig` is often newer than 0.14. |
| lwtools 4.25 | Provides `lwasm` | Source build below. There is no Homebrew bottle. |
| RetroArch | Vectrex window | [retroarch.com](https://retroarch.com/) macOS build. Copy `RetroArch.app` to `/Applications`. Open it once and allow it if Gatekeeper asks. |
| vecx core | Emulator. No Vectrex BIOS file is required. | In RetroArch: **Online Updater → Core Downloader → Vectrex (vecx)**. The file must land at `~/Library/Application Support/RetroArch/cores/vecx_libretro.dylib`. |

Zig 0.14.1 for a Mac:

```sh
# Apple silicon
curl -fsSL -o zig.tar.xz https://ziglang.org/download/0.14.1/zig-aarch64-macos-0.14.1.tar.xz
# Intel
curl -fsSL -o zig.tar.xz https://ziglang.org/download/0.14.1/zig-x86_64-macos-0.14.1.tar.xz

tar -xJf zig.tar.xz
# Then put that directory on your PATH, or call ./zig-aarch64-macos-0.14.1/zig
```

`lwasm`:

```sh
curl -fsSL -o lwtools.tar.gz https://www.lwtools.ca/releases/lwtools/lwtools-4.25.tar.gz
tar -xzf lwtools.tar.gz
make -C lwtools-4.25
sudo make -C lwtools-4.25 install
```

### Each local build

From the repository root, after the requirements above are done:

```sh
zig build
```

That writes both cartridges and runs:

```text
/Applications/RetroArch.app/Contents/MacOS/RetroArch \
  -L "$HOME/Library/Application Support/RetroArch/cores/vecx_libretro.dylib" \
  zig-out/bin/smile.bin
```

The window is the Vectrex screen. The smile demo plays itself: an ellipse, a tail that grows when the face is fast, then `GOODBYE WORLD`. Close the window to finish `zig build`.

```sh
zig build -Drom=hello          # open the static HELLO WORLD cartridge instead
zig build -Dlaunch=false       # write the bins and return immediately
zig build -Dlaunch=true        # same as the default on a Mac; ignored on Linux and CI
```

If RetroArch or the vecx core is missing, the ROMs are still written and the build exits with the install steps. Fix that once. The next `zig build` loads the ROM again.

You can also load a bin by hand. RetroArch → **Load Content** → `zig-out/bin/smile.bin`, with the vecx core. Or repeat the command above.

## Build on Linux

You need Zig 0.14 and `lwasm` on `PATH`. Ubuntu 24.04 does not package lwtools, so build it:

```sh
curl -fsSL -o lwtools.tar.gz https://www.lwtools.ca/releases/lwtools/lwtools-4.25.tar.gz
tar -xzf lwtools.tar.gz
make -C lwtools-4.25
sudo make -C lwtools-4.25 install

zig build
```

A Linux or CI build never opens an emulator. `tools/launch-mac.sh` returns immediately unless it is running on macOS. Use the bins with any vecx or MAME Vectrex driver. MAME's `vectrex` driver also needs a BIOS dump you own (`vectrex.zip`). vecx in RetroArch does not.

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

You do not need Zig or `lwasm` to play a cartridge. Every green **Build ROMs** run uploads a `vectrex-roms` zip. Inside it:

```text
bin/hello.bin    static HELLO WORLD cartridge
bin/smile.bin    orbiting smiley
hello.s          generated assembly
smile.s
```

### In the browser

1. Open [Actions](https://github.com/nxnlvz/zig2vec/actions) and choose **Build ROMs**.
2. Open the newest run whose icon is green. A push to `main` starts one on its own. Otherwise use **Run workflow**.
3. Scroll to **Artifacts** and download `vectrex-roms`.
4. Unzip it. On a Mac, double-click the zip in Downloads.

### From the command line

[GitHub CLI](https://cli.github.com/), logged in so it can read the repository:

```sh
gh run download -R nxnlvz/zig2vec -n vectrex-roms -D ~/vectrex-roms
```

That writes `~/vectrex-roms/bin/smile.bin` and `~/vectrex-roms/bin/hello.bin`.

### Load it on a Mac

RetroArch and the vecx core are the same requirements as a local build. No Vectrex BIOS file.

1. If you have not already: install [RetroArch](https://retroarch.com/), copy `RetroArch.app` to `/Applications`, open it once, and allow it if Gatekeeper asks.
2. In RetroArch: **Online Updater → Core Downloader → Vectrex (vecx)**.
3. Either load the file from the menu, or start it from Terminal:

```sh
/Applications/RetroArch.app/Contents/MacOS/RetroArch \
  -L "$HOME/Library/Application Support/RetroArch/cores/vecx_libretro.dylib" \
  "$HOME/vectrex-roms/bin/smile.bin"
```

Use `bin/hello.bin` for the static screen. **Load Content** in the RetroArch menu is the same thing: pick the `.bin`, and if asked for a core pick **Vectrex (vecx)**.

The smile cartridge plays itself. Close the window when you are done. Nothing here is installed into RetroArch; the next download replaces the zip, and you point the emulator at the new `bin/smile.bin`.

## Play in the browser

[jsvecx](https://drsnuggles.github.io/jsvecx/) can open a cartridge from `?rom=` when that value is a public `http` URL. The page fetches it through its own proxy, so the file does not need CORS headers.

These two links are the cartridges from the latest build on `main`. Each green **Build ROMs** run copies `hello.bin` and `smile.bin` to `roms/` after it finishes, and a push that only changes `roms/` does not start another build.

- [Smile](https://drsnuggles.github.io/jsvecx/?rom=https://raw.githubusercontent.com/nxnlvz/zig2vec/main/roms/smile.bin)
- [Hello](https://drsnuggles.github.io/jsvecx/?rom=https://raw.githubusercontent.com/nxnlvz/zig2vec/main/roms/hello.bin)

The Actions artifact itself cannot go in `?rom=`. That URL needs a GitHub login, and the zip contains both cartridges plus the assembly. jsvecx would not know which `.bin` you meant.

To play one specific run instead of whatever is on `main`:

1. Download `vectrex-roms` as above and unzip it.
2. Open [jsvecx](https://drsnuggles.github.io/jsvecx/).
3. Drag `bin/smile.bin` or `bin/hello.bin` onto the page.

The smile cartridge plays itself. There is no BIOS file to add.
