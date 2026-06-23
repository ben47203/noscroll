#!/bin/bash
# noscroll uninstaller — removes the LaunchAgent and the installed binary.
# Requires your password and respects the cooldown, by design.
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local/bin}"
DEST="$PREFIX/noscroll"
BIN="$(command -v noscroll || echo "$DEST")"

if [ ! -x "$BIN" ]; then
  echo "noscroll does not appear to be installed."
  exit 1
fi

echo "This removes the LaunchAgent (password required)…"
"$BIN" uninstall

rm -f "$BIN"
echo "Removed $BIN"
echo
echo "Left in place (delete manually if you really want to):"
echo "  ~/.noscroll_sites   ~/.noscroll_hash"
