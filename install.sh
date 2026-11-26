#!/bin/bash
# noscroll installer.
#
#   From a checkout:   ./install.sh
#   One line:          curl -fsSL https://raw.githubusercontent.com/ben47203/noscroll/main/install.sh | bash
#
# Copies noscroll into ~/Library/Application Support/noscroll, links it as
# ~/.local/bin/noscroll, asks how unlocking should work, and starts the
# login agent + watchdog. Re-running it on an existing install queues an
# upgrade (password and/or delay, like any other change).
set -euo pipefail

REPO="${NOSCROLL_REPO:-ben47203/noscroll}"
REF="${NOSCROLL_REF:-main}"

[ "$(uname)" = "Darwin" ] || { echo "noscroll only runs on macOS."; exit 1; }

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/noscroll" ]; then
  SRC="$SRC_DIR/noscroll"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Downloading noscroll ($REF)…"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/noscroll" -o "$TMP/noscroll"
  chmod +x "$TMP/noscroll"
  SRC="$TMP/noscroll"
fi

# When piped into bash, stdin is this script — prompts need the terminal.
if [ -t 0 ]; then
  /bin/bash "$SRC" install
else
  /bin/bash "$SRC" install < /dev/tty
fi
