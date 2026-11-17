#!/bin/bash
# Legend of Lion Turtle — rebuild the Mac app from this repo and install it.
#
#   ./update_app.sh            rebuild from the project, install to /Applications, open it
#   ./update_app.sh --no-build install the app already in build/ (no Godot needed)
#
# What it does:
#   1. Exports project/ with Godot 4.4 (preset "macOS") to build/Legend of Lion Turtle.zip.
#      The first time, it fetches Godot's macOS export template (about 1.2 GB
#      download; only the 116 MB macOS part is kept).
#   2. Quits the running game, replaces /Applications/Legend of Lion Turtle.app,
#      clears the download quarantine flag, and opens it.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
APP_NAME="Legend of Lion Turtle"
ZIP="$REPO/build/$APP_NAME.zip"
DEST="/Applications/$APP_NAME.app"
TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/4.4.stable"
TPL_URL="https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_export_templates.tpz"

say() { printf "\033[1;33m▸ %s\033[0m\n" "$1"; }

if [[ "${1:-}" != "--no-build" ]]; then
  [[ -x "$GODOT" ]] || { echo "Godot not found at $GODOT (set GODOT=/path/to/Godot)"; exit 1; }

  if [[ ! -f "$TPL_DIR/macos.zip" ]]; then
    say "Downloading Godot 4.4 export templates (one time, ~1.2 GB)..."
    TMP="$(mktemp -d)"
    curl -L --progress-bar -o "$TMP/templates.tpz" "$TPL_URL"
    mkdir -p "$TPL_DIR"
    unzip -o -j "$TMP/templates.tpz" templates/macos.zip templates/version.txt -d "$TPL_DIR" >/dev/null
    rm -rf "$TMP"
  fi

  say "Importing assets..."
  "$GODOT" --headless --path "$REPO/project" --import >/dev/null 2>&1 || true

  say "Exporting the Mac app..."
  mkdir -p "$REPO/build"
  rm -f "$ZIP"
  "$GODOT" --headless --path "$REPO/project" --export-release "macOS" "$ZIP" 2>&1 | grep -E "ERROR" || true
  [[ -f "$ZIP" ]] || { echo "Export failed — open the project in Godot to see why."; exit 1; }
fi

[[ -f "$ZIP" ]] || { echo "No build at $ZIP — run without --no-build first."; exit 1; }

say "Installing to $DEST..."
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
sleep 1
TMP="$(mktemp -d)"
ditto -x -k "$ZIP" "$TMP"
rm -rf "$DEST"
mv "$TMP/$APP_NAME.app" "$DEST"
rm -rf "$TMP"
xattr -cr "$DEST" 2>/dev/null || true

say "Opening $APP_NAME..."
open "$DEST"
echo "Done. To share it: AirDrop build/$APP_NAME.zip (or the app in Applications)."
