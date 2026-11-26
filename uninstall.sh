#!/bin/bash
# noscroll uninstaller — a thin wrapper around `noscroll uninstall`.
# By design this goes through the normal unlock rules: your password (in
# password mode) and the configured delay before anything is removed.
set -euo pipefail

BIN="$(command -v noscroll || echo "$HOME/.local/bin/noscroll")"
[ -x "$BIN" ] || { echo "noscroll doesn't appear to be installed."; exit 1; }
exec "$BIN" uninstall
