#!/bin/bash
# noscroll installer — copies the script onto your PATH, sets a password,
# and registers the LaunchAgent so the blocker survives reboots and kills.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local/bin}"
DEST="$PREFIX/noscroll"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "noscroll only works on macOS (it drives Chrome/Safari via AppleScript)."
  exit 1
fi

echo "Installing noscroll to $DEST"
mkdir -p "$PREFIX"
install -m 755 "$SRC_DIR/noscroll" "$DEST"

if ! command -v noscroll >/dev/null 2>&1; then
  echo
  echo "⚠️  $PREFIX is not on your PATH. Add this to your shell profile:"
  echo "      export PATH=\"$PREFIX:\$PATH\""
  echo
fi

echo "Set a password (needed to stop/uninstall the blocker)…"
"$DEST" setup-password

echo
echo "Registering the LaunchAgent…"
"$DEST" install

echo
echo "✅ Done. noscroll is running and will block its default sites."
echo "   Try:  noscroll status"
echo "         noscroll add reddit.com"
echo "         noscroll help"
