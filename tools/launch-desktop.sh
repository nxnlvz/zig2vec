#!/bin/sh
# Open one cartridge in RetroArch's vecx core on the environment desktop.
# zig build does not call this. CI does not call this.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
rom=${1:-}
if [ -z "$rom" ]; then
  if [ -f "$root/zig-out/bin/smile.bin" ]; then
    rom=$root/zig-out/bin/smile.bin
  else
    rom=$root/roms/smile.bin
  fi
fi
if [ ! -f "$rom" ]; then
  echo "zig2vec: no cartridge at ${rom}." >&2
  echo "Build one with: zig build -Dlaunch=false" >&2
  exit 1
fi
case "$rom" in
  /*) ;;
  *) rom=$(CDPATH= cd -- "$(dirname "$rom")" && pwd)/$(basename "$rom") ;;
esac

if [ -z "${DISPLAY:-}" ]; then
  for sock in /tmp/.X11-unix/X*; do
    if [ -S "$sock" ]; then
      DISPLAY=:${sock#/tmp/.X11-unix/X}
      export DISPLAY
    fi
  done
fi
if [ -z "${DISPLAY:-}" ]; then
  echo "zig2vec: no X display. Open the environment desktop, then run tools/launch-desktop.sh again." >&2
  exit 1
fi

if ! command -v retroarch >/dev/null 2>&1; then
  echo "zig2vec: retroarch is not installed." >&2
  exit 1
fi

core=""
for candidate in \
  /usr/local/lib/libretro/vecx_libretro.so \
  /usr/lib/x86_64-linux-gnu/libretro/vecx_libretro.so \
  /usr/lib/libretro/vecx_libretro.so
do
  if [ -f "$candidate" ]; then
    core=$candidate
    break
  fi
done
if [ -z "$core" ]; then
  echo "zig2vec: vecx_libretro.so is not installed." >&2
  echo "Expected /usr/local/lib/libretro/vecx_libretro.so." >&2
  exit 1
fi

cfg=/tmp/zig2vec-retroarch.cfg
cat > "$cfg" << 'EOF'
video_driver = "gl"
video_fullscreen = "false"
video_windowed_fullscreen = "false"
video_smooth = "false"
video_force_aspect = "true"
audio_enable = "false"
pause_nonactive = "false"
video_font_enable = "false"
quit_press_twice = "false"
EOF

echo "zig2vec: launching ${rom} on ${DISPLAY}" >&2
exec retroarch --appendconfig "$cfg" -L "$core" "$rom"
