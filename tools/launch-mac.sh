#!/bin/sh
# Open one cartridge in RetroArch's vecx core. build.zig only runs this on a
# local macOS build. CI never calls it.
set -eu

rom=${1:?usage: launch-mac.sh rom.bin}

if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
  exit 0
fi

retroarch=""
for candidate in \
  "/Applications/RetroArch.app/Contents/MacOS/RetroArch" \
  "$HOME/Applications/RetroArch.app/Contents/MacOS/RetroArch"
do
  if [ -x "$candidate" ]; then
    retroarch=$candidate
    break
  fi
done
if [ -z "$retroarch" ] && command -v retroarch >/dev/null 2>&1; then
  retroarch=$(command -v retroarch)
fi

core=""
for candidate in \
  "$HOME/Library/Application Support/RetroArch/cores/vecx_libretro.dylib"
do
  if [ -f "$candidate" ]; then
    core=$candidate
    break
  fi
done

if [ -z "$retroarch" ] || [ -z "$core" ]; then
  echo "zig2vec: this Mac build did not launch ${rom}." >&2
  echo "Install RetroArch and the Vectrex (vecx) core, then run zig build again." >&2
  echo "  1. Download the macOS build from https://retroarch.com/ and copy RetroArch.app to /Applications." >&2
  echo "  2. Open RetroArch once so Gatekeeper can allow it." >&2
  echo "  3. Online Updater -> Core Downloader -> Vectrex (vecx)." >&2
  echo "  Expected core: ~/Library/Application Support/RetroArch/cores/vecx_libretro.dylib" >&2
  echo "Build without launching: zig build -Dlaunch=false" >&2
  exit 1
fi

echo "zig2vec: launching ${rom}" >&2
echo "Quit RetroArch to let zig build finish." >&2
exec "$retroarch" -L "$core" "$rom"
