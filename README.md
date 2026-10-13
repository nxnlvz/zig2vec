# zig2vec

Zig runs on the host. It prints 6809 assembly, and `lwasm` turns that into a Vectrex cartridge. The 6809 does not run Zig. There is no 6809 backend. A game is a Zig function that appends assembly text.

A `.bin` from this project is a raw cartridge image, not an ELF. No Vectrex BIOS file is required for RetroArch's vecx core or for jsvecx.

## Play the smile cartridge

The latest build on `main` is already published. Open this URL:

```text
https://drsnuggles.github.io/jsvecx/?rom=https://raw.githubusercontent.com/nxnlvz/zig2vec/main/roms/smile.bin
```

Hello World, the same way:

```text
https://drsnuggles.github.io/jsvecx/?rom=https://raw.githubusercontent.com/nxnlvz/zig2vec/main/roms/hello.bin
```

[jsvecx](https://drsnuggles.github.io/jsvecx/) reads `?rom=` only when the value is a public `http` URL. It fetches that file through `https://simpleproxy.drsnuggles.workers.dev`, so the ROM host does not need CORS headers. The smile cartridge plays itself: an ellipse, a tail that grows when the face is fast, then `GOODBYE WORLD`.

Those two links follow `roms/hello.bin` and `roms/smile.bin` on `main`. Every green **Build ROMs** run copies the new bins there. A commit that only changes `roms/` does not start another build.

The Actions artifact zip cannot be pasted into `?rom=`. That URL needs a GitHub login, and the zip holds both cartridges plus the assembly. To play one specific run, download the artifact (below) and drag `bin/smile.bin` onto the jsvecx page.

## Play a GitHub Actions build

You do not need Zig or `lwasm` for this. Every green run of **Build ROMs** uploads `vectrex-roms`. After you unzip it:

```text
bin/hello.bin    static HELLO WORLD cartridge
bin/smile.bin    orbiting smiley
hello.s          generated assembly
smile.s
```

### Download in the browser

1. Open [Actions](https://github.com/nxnlvz/zig2vec/actions/workflows/build.yml) and choose the newest green **Build ROMs** run. A push to `main` starts one. You can also use **Run workflow**.
2. Scroll to **Artifacts** and download `vectrex-roms`.
3. Unzip it. On a Mac, double-click the zip in Downloads.

If the Actions tab says workflows are disabled, go to **Settings → Actions → General** and allow actions.

### Download with the GitHub CLI

[GitHub CLI](https://cli.github.com/), logged in so it can read the repository:

```sh
gh run download -R nxnlvz/zig2vec -n vectrex-roms -D ~/vectrex-roms
```

That writes `~/vectrex-roms/bin/smile.bin` and `~/vectrex-roms/bin/hello.bin`.

### Load that zip in jsvecx

1. Open https://drsnuggles.github.io/jsvecx/
2. Drag `bin/smile.bin` or `bin/hello.bin` onto the page.

### Load that zip in RetroArch on a Mac

1. Install the macOS build from https://retroarch.com/ and copy `RetroArch.app` to `/Applications`.
2. Open RetroArch once and allow it if Gatekeeper asks.
3. **Online Updater → Core Downloader → Vectrex (vecx)**. The core file must be `~/Library/Application Support/RetroArch/cores/vecx_libretro.dylib`.
4. Start the cartridge:

```sh
/Applications/RetroArch.app/Contents/MacOS/RetroArch \
  -L "$HOME/Library/Application Support/RetroArch/cores/vecx_libretro.dylib" \
  "$HOME/vectrex-roms/bin/smile.bin"
```

Use `bin/hello.bin` for the static screen. **Load Content** in the RetroArch menu is the same step: pick the `.bin`, and if it asks for a core pick **Vectrex (vecx)**. Nothing is installed into RetroArch. The next download replaces the files, and you point the emulator at the new `bin/smile.bin`.

## Build on a Mac and open the ROM

`zig build` on macOS writes both cartridges, then opens `zig-out/bin/smile.bin` in RetroArch and waits. Quit RetroArch and the command returns. Linux and GitHub Actions do not open a window.

### Requirements

| Tool | Why | How |
|---|---|---|
| Xcode Command Line Tools | `make` and `clang` for `lwasm` | `xcode-select --install` |
| Zig 0.14.1 | Host compiler. 0.15 and later will not build this tree (`std.posix`). | Tarball below. `brew install zig` is often newer than 0.14. |
| lwtools 4.25 | Provides `lwasm`. No Homebrew bottle. | Source build below. |
| RetroArch | Vectrex window | https://retroarch.com/ macOS build, copied to `/Applications`. Open it once. |
| vecx core | Emulator. No BIOS file. | **Online Updater → Core Downloader → Vectrex (vecx)** |

Zig 0.14.1:

```sh
# Apple silicon
curl -fsSL -o zig.tar.xz https://ziglang.org/download/0.14.1/zig-aarch64-macos-0.14.1.tar.xz
# Intel
curl -fsSL -o zig.tar.xz https://ziglang.org/download/0.14.1/zig-x86_64-macos-0.14.1.tar.xz

tar -xJf zig.tar.xz
```

Put that directory on `PATH`, or call the `zig` binary inside it.

`lwasm`:

```sh
curl -fsSL -o lwtools.tar.gz https://www.lwtools.ca/releases/lwtools/lwtools-4.25.tar.gz
tar -xzf lwtools.tar.gz
make -C lwtools-4.25
sudo make -C lwtools-4.25 install
```

### Each local build

From the repository root:

```sh
zig build
```

That writes the files in the output table below and runs:

```text
/Applications/RetroArch.app/Contents/MacOS/RetroArch \
  -L "$HOME/Library/Application Support/RetroArch/cores/vecx_libretro.dylib" \
  zig-out/bin/smile.bin
```

```sh
zig build -Drom=hello       # open HELLO WORLD instead
zig build -Dlaunch=false    # write the bins and return
zig build -Dlaunch=true     # same as the default on a Mac; no window on Linux or CI
```

If RetroArch or the vecx core is missing, the bins are still written and the command prints the install steps, then exits non-zero. Fix that once. The next `zig build` loads the ROM.

You can also open a bin yourself. RetroArch → **Load Content** → `zig-out/bin/smile.bin`, with the vecx core.

## Build on Linux

Same Zig 0.14.1 and lwtools 4.25. Ubuntu 24.04 does not package lwtools:

```sh
curl -fsSL -o zig.tar.xz https://ziglang.org/download/0.14.1/zig-x86_64-linux-0.14.1.tar.xz
tar -xJf zig.tar.xz
# put zig-x86_64-linux-0.14.1 on PATH

curl -fsSL -o lwtools.tar.gz https://www.lwtools.ca/releases/lwtools/lwtools-4.25.tar.gz
tar -xzf lwtools.tar.gz
make -C lwtools-4.25
sudo make -C lwtools-4.25 install

zig build
```

`zig build` only writes the bins. `tools/launch-mac.sh` returns immediately unless it is running on macOS. MAME's `vectrex` driver can load a bin, and it also needs a BIOS dump you own (`vectrex.zip`). RetroArch vecx and jsvecx do not.

On the environment desktop, RetroArch and the vecx core are already installed. From the repository root:

```sh
tools/launch-desktop.sh
tools/launch-desktop.sh roms/hello.bin
```

With no argument it opens `zig-out/bin/smile.bin` when that file exists, and `roms/smile.bin` otherwise. The window uses `DISPLAY` when that is set, and otherwise the X socket under `/tmp/.X11-unix`. Quit RetroArch to return to the shell.

## Output of `zig build`

| File | What it is |
|---|---|
| `zig-out/hello.s` | assembly for the hello cartridge |
| `zig-out/bin/hello.bin` | hello ROM |
| `zig-out/smile.s` | assembly for the smile cartridge |
| `zig-out/bin/smile.bin` | smile ROM |

`build.zig` compiles each example, captures stdout, and runs `lwasm --format=raw -o <name>.bin <name>.s`. `lwasm` rejects `--output` unless the filename is attached with `=`, so the build uses `-o`.

## What GitHub Actions does

`.github/workflows/build.yml` is **Build ROMs**. It runs on a push to `main` (except a push that only touches `roms/`), on a pull request, and on **Run workflow**.

The job uses `ubuntu-latest`. It downloads Zig 0.14.1, builds lwtools 4.25, runs `zig build`, uploads `vectrex-roms`, and on a push (not on a pull request) copies `hello.bin` and `smile.bin` to `roms/` and pushes that if the bytes changed. That is what the jsvecx URLs above point at.

## Layout

```text
src/root.zig                 library: assembly writer, BIOS addresses, cartridge header
examples/hello/              static HELLO WORLD cartridge
examples/smile/              orbiting smiley with a velocity-scaled tail
tools/launch-mac.sh          opens one ROM in RetroArch; local macOS builds only
tools/launch-desktop.sh      opens one ROM in RetroArch on the Linux desktop
roms/hello.bin               public hello cartridge for jsvecx; CI writes this
roms/smile.bin               public smile cartridge for jsvecx; CI writes this
build.zig                    one ROM step per example
.github/workflows/build.yml  GitHub Actions build
```

`src/` does not know about a particular game. An example imports it as `zig2vec` and fills an `Asm` buffer. Do not edit `roms/*.bin` by hand.

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

## Add an example

1. Create `examples/<name>/main.zig`.
2. `@import("zig2vec")`, fill an `Asm`, and write it with `writeStdout` from `main`.
3. Add a row to the `examples` array in `build.zig`.

`zig build` then emits `zig-out/bin/<name>.bin`. The Actions artifact includes every `zig-out/bin/*.bin`. The browser publish step currently copies only `hello.bin` and `smile.bin` to `roms/`. Add the new file there, in `.github/workflows/build.yml`, if it should have a jsvecx URL.
