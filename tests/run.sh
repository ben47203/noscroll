#!/bin/bash
# shellcheck disable=SC2034  # globals are read by the sourced noscroll functions
# noscroll test suite — runs entirely in a temp sandbox; never touches your
# real install, launchd, or browsers.
#
#   ./tests/run.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/noscroll-test.XXXXXX")"
trap 'chflags -R nouchg "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT

export NOSCROLL_DRY=1
export NOSCROLL_HOME="$SANDBOX/home"
export NOSCROLL_APP_DIR="$SANDBOX/app"
export NOSCROLL_AGENTS_DIR="$SANDBOX/agents"
export NOSCROLL_LINK="$SANDBOX/bin/noscroll"
export NOSCROLL_LABEL="test.noscroll.agent"
# Keep v1 migration away from the real $HOME.
export HOME="$SANDBOX/fakehome"
mkdir -p "$HOME"

# shellcheck disable=SC1091
. "$ROOT/noscroll"
exec 3<&0
NS="$ROOT/noscroll"

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); printf '  ✗ %s\n' "$*"; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1: expected [$3] got [$2]"; fi; }
section() { printf '%s\n' "$*"; }

# ── durations ────────────────────────────────────────────────────────────
section "durations"
eq "90s"   "$(parse_duration 90s)" 90
eq "1h30m" "$(parse_duration 1h30m)" 5400
eq "2d"    "$(parse_duration 2d)" 172800
eq "bare"  "$(parse_duration 45)" 45
eq "08m"   "$(parse_duration 08m)" 480
parse_duration "abc" >/dev/null && fail "abc should not parse" || ok
eq "fmt 5400"  "$(fmt_duration 5400)" "1h 30m"
eq "fmt 0"     "$(fmt_duration 0)" "0s"
eq "fmt 86400" "$(fmt_duration 86400)" "1d"

# ── hex ──────────────────────────────────────────────────────────────────
section "hex"
eq "encode" "$(hex_encode reddit.com)" "7265646469742e636f6d"
eq "decode" "$(hex_decode 7265646469742e636f6d)" "reddit.com"
is_hex "7265" && ok || fail "is_hex valid"
is_hex "726" && fail "odd hex accepted" || ok
is_hex "zz" && fail "non-hex accepted" || ok

# ── pattern normalisation ────────────────────────────────────────────────
section "normalise"
n() { normalise_pattern "$1" 2>/dev/null; }
eq "scheme+www"   "$(n 'https://www.Reddit.com/')"   "reddit.com"
eq "path"         "$(n 'linkedin.com/feed/')"         "linkedin.com/feed"
eq "glob tail"    "$(n 'reddit.com/*')"               "reddit.com"
eq "subdomains"   "$(n '*.example.com')"              "*.example.com"
eq "exact"        "$(n '=www.example.com')"           "=www.example.com"
eq "keyword"      "$(n '~Casino')"                    "~casino"
eq "port"         "$(n 'localhost:3000/app')"         "localhost/app"
n "reddit" >/dev/null && fail "bare word accepted as domain" || ok
n "red dit.com" >/dev/null && fail "space accepted" || ok
n 'a"b.com' >/dev/null && fail "quote accepted" || ok

# ── rule lines ───────────────────────────────────────────────────────────
section "rule lines"
parse_line "!hex:$(hex_encode reddit.com/r/swift) grace=60 limit=1800"
eq "kind"   "$R_KIND" allow
eq "pat"    "$R_PAT" "reddit.com/r/swift"
eq "hidden" "$R_HIDDEN" 1
eq "grace"  "$R_GRACE" 60
eq "limit"  "$R_LIMIT" 1800
parse_line "# comment" && fail "comment parsed" || ok
eq "compose" "$(compose_line block youtube.com 0 0 1800)" "youtube.com limit=1800"
eq "compose hidden" "$(compose_line allow a.com 1 0 0)" "!hex:612e636f6d"

section "strictness"
is_weaker 0 0 60 0     && ok || fail "adding grace is weaker"
is_weaker 0 0 0 1800   && ok || fail "adding limit is weaker"
is_weaker 0 1800 0 3600 && ok || fail "raising limit is weaker"
is_weaker 0 1800 0 600 && fail "lowering limit is not weaker" || ok
is_weaker 0 1800 0 0   && fail "full block is not weaker" || ok
is_weaker 60 0 30 0    && fail "shorter grace is not weaker" || ok

# ── signed files ─────────────────────────────────────────────────────────
section "signing"
ensure_home
printf 'a\nb\n' | swrite "$F_CONFIG" protect
sverify "$F_CONFIG" && ok || fail "fresh file verifies"
[[ "$(stat -f %Sf "$F_CONFIG")" == *uchg* ]] && ok || fail "protected file is immutable"
chflags nouchg "$F_CONFIG"; printf 'evil\n' >> "$F_CONFIG"
sverify "$F_CONFIG" && fail "tampered file verifies" || ok
check_protected "$F_CONFIG"
sverify "$F_CONFIG" && ok || fail "tampered file restored from backup"
eq "restored body" "$(sbody "$F_CONFIG" | tr '\n' ,)" "a,b,"
sremove "$F_CONFIG"

# ── URL matching ─────────────────────────────────────────────────────────
section "matching"
cat <<EOF | swrite "$F_SITES" protect
reddit.com
!reddit.com/r/swift
x.com
linkedin.com/feed
*.example.org
=m.example.net
~casino
hex:$(hex_encode secret-site.com)
youtube.com/shorts
EOF
m() { match_url "$1"; }
eq "apex"            "$(m https://reddit.com/)"                  1
eq "subdomain"       "$(m https://old.reddit.com/r/pics)"        1
eq "allow beats"     "$(m https://www.reddit.com/r/swift/top)"   ""
eq "allow boundary"  "$(m https://reddit.com/r/swiftui)"         1
eq "x.com"           "$(m https://x.com/home)"                   3
eq "no netflix"      "$(m https://www.netflix.com/browse)"       ""
eq "no dropbox"      "$(m https://dropbox.com/)"                 ""
eq "path"            "$(m https://www.linkedin.com/feed/?x=1)"   4
eq "path other"      "$(m https://www.linkedin.com/in/someone)"  ""
eq "path boundary"   "$(m https://linkedin.com/feedback)"        ""
eq "sub only"        "$(m https://a.b.example.org/)"             5
eq "sub not apex"    "$(m https://example.org/)"                 ""
eq "exact"           "$(m https://m.example.net/x)"              6
eq "exact not sub"   "$(m https://a.m.example.net/x)"            ""
eq "keyword"         "$(m https://news.com/?q=CASINO+tips)"      7
eq "hidden"          "$(m https://secret-site.com/)"             8
eq "port+user"       "$(m https://u@reddit.com:443/)"            1
eq "query only"      "$(m https://youtube.com?v=1)"              ""
eq "shorts"          "$(m https://m.youtube.com/shorts/abc)"     9
eq "not in query"    "$(m https://google.com/search?q=reddit.com)" ""
eq "empty"           "$(m '')"                                   ""

# ── CLI end to end (launchctl stubbed) ───────────────────────────────────
section "cli"
sremove "$F_SITES"
run() { "$NS" "$@" 2>&1; }
printf 'hunter22\nhunter22\n' | run setup-password > "$SANDBOX/pw.out"
grep -q "Password set" "$SANDBOX/pw.out" && ok || fail "setup-password"
CODE=$(grep -Eo '[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}' "$SANDBOX/pw.out")
[ -n "$CODE" ] && ok || fail "recovery code printed"

run install >/dev/null
[ -f "$NOSCROLL_APP_DIR/noscroll" ] && ok || fail "binary installed"
[ -L "$NOSCROLL_LINK" ] && ok || fail "command symlinked"
[ -f "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.plist" ] && ok || fail "agent plist"
[ -f "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.watchdog.plist" ] && ok || fail "watchdog plist"
plutil -lint "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.plist" >/dev/null && ok || fail "agent plist is valid"
plutil -lint "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.watchdog.plist" >/dev/null && ok || fail "watchdog plist is valid"
run list | grep -q "instagram.com" && ok || fail "default sites seeded"

run add news.ycombinator.com >/dev/null
run list --raw | grep -qx "news.ycombinator.com" && ok || fail "add is immediate"
run add --hex "$(hex_encode hidden.example.com)" >/dev/null
run list --raw | grep -qx "hex:$(hex_encode hidden.example.com)" && ok || fail "add --hex stores hex"
run list | grep -q "hidden.example.com" && fail "hidden site shown in list" || ok
run list --reveal | grep -q "hidden.example.com" && ok || fail "list --reveal"
printf 'prompted.example.com\n' | run add --prompt >/dev/null
run list --raw | grep -qx "hex:$(hex_encode prompted.example.com)" && ok || fail "add --prompt stores hex"

# Loosening is queued, tightening is not.
run add youtube.com --limit 30m >/dev/null 2>&1 <<< "hunter22"
run list --raw | grep -qx "youtube.com" && ok || fail "limit on a full block is queued, not applied"
run pending | grep -q "Loosen" && ok || fail "loosen request is pending"
run cancel all >/dev/null
[ -z "$(pending_lines)" ] && ok || fail "cancel all"
run limit tiktok.com 1h <<< "hunter22" >/dev/null
run limit newsite.com 20m >/dev/null
run list --raw | grep -qx "newsite.com limit=1200" && ok || fail "limit on a new site is immediate"
run limit newsite.com 10m >/dev/null
run list --raw | grep -qx "newsite.com limit=600" && ok || fail "lowering a limit is immediate"
run cancel all >/dev/null

# Wrong password is rejected; right password queues; recovery code works.
run remove reddit.com <<< "nope" | grep -q "Wrong password" && ok || fail "wrong password rejected"
run remove reddit.com <<< "hunter22" | grep -q "Queued #" && ok || fail "remove queued with password"
run remove x.com <<< "$CODE" | grep -q "Queued #" && ok || fail "recovery code accepted"
run list --raw | grep -qx "reddit.com" && ok || fail "removal not applied before delay"

# Fast-forward the queue: re-sign it with created=0 (what time passing does).
lock; sbody "$F_PENDING" | awk -F'|' -v OFS='|' '{ $2 = 0; print }' | swrite "$F_PENDING"; unlock
process_pending
run list --raw | grep -qx "reddit.com" && fail "removal applied after delay" || ok
run list --raw | grep -qx "x.com" && fail "second removal applied" || ok

# Hand-edited queue is discarded, not obeyed.
run remove instagram.com <<< "hunter22" >/dev/null
chflags nouchg "$F_PENDING" 2>/dev/null
sed -i '' 's/^\([0-9]*\)|[0-9]*|/\1|0|/' "$F_PENDING"
process_pending
run list --raw | grep -qx "instagram.com" && ok || fail "forged queue entry ignored"

# Tampering with the blocklist is reverted.
chflags nouchg "$F_SITES"; printf 'oops\n' > "$F_SITES"
run list --raw 2>/dev/null | grep -qx "instagram.com" && ok || fail "tampered blocklist restored"

# Allow rules: adding is queued, removing is immediate.
run allow reddit.com/r/swift <<< "hunter22" | grep -q "Queued" && ok || fail "allow is queued"
apply_action upsert "!reddit.com/r/swift"
run remove reddit.com/r/swift | grep -q "Removed the exception" && ok || fail "removing allow is immediate"

# Hide / unhide.
run hide all >/dev/null
run list --raw | grep -vq '^hex:' && fail "hide all left plain rules" || ok
run unhide '#1' >/dev/null
run list --raw | head -1 | grep -q '^hex:' && fail "unhide #1" || ok

# check command
run check https://www.instagram.com/reels | grep -q "Blocked by rule" && ok || fail "check blocked"
run check https://example.com | grep -q "Allowed" && ok || fail "check allowed"

# Timer mode: no password, every weakening waits.
run mode timer --delay 1h <<< "hunter22" | grep -q "Queued" && ok || fail "password→timer is queued"
apply_action config "mode=timer,delay=3600"
eq "timer mode" "$(cfg mode)" timer
run stop </dev/null | grep -q "Takes effect in 1h" && ok || fail "timer stop needs no password"
run forgot | grep -q "timer mode" && ok || fail "forgot explains timer mode"
run cancel all >/dev/null

# Forgot password (password mode).
apply_action config "mode=password,delay=600"
run forgot </dev/null | grep -q "Queued" && ok || fail "forgot queues recovery"
run pending | grep -q "Forgotten password" && ok || fail "recovery is pending"
lock; sbody "$F_PENDING" | awk -F'|' -v OFS='|' '{ $2 = 0; print }' | swrite "$F_PENDING"; unlock
process_pending
has_password && fail "recovery cleared the password" || ok
is_stopped && ok || fail "recovery stopped the blocker"

# While stopped, changes apply immediately.
run remove instagram.com | grep -q "Done" && ok || fail "stopped: remove is immediate"
run start >/dev/null
is_stopped && fail "start clears stop" || ok

# Usage file tamper → limits exhausted.
RULE_COUNT=1; RULE_LIMIT[1]=600; RULE_KEY[1]=abc; USED[1]=0; USAGE_DATE=$(date +%F)
persist_usage
chflags nouchg "$F_USAGE" 2>/dev/null; sed -i '' 's/ abc 0/ abc 1/' "$F_USAGE"
load_usage "$(date +%F)"
eq "usage tamper exhausts" "${USED[1]}" 600

# ── AppleScript compiles for installed browsers ──────────────────────────
section "applescript"
while IFS='|' read -r name _ fam; do
  if [ -d "/Applications/$name.app" ] || { [ "$name" = Safari ] && [ -d /System/Cryptexes/App/System/Applications/Safari.app ]; }; then
    osacompile -o "$SANDBOX/d.scpt" -e "$(dump_script "$name" "$fam")" 2>"$SANDBOX/err" && ok || fail "$name dump script: $(cat "$SANDBOX/err")"
    osacompile -o "$SANDBOX/c.scpt" -e "$(close_script "$name" '{1, 1, "x"}')" 2>"$SANDBOX/err" && ok || fail "$name close script: $(cat "$SANDBOX/err")"
  fi
done <<< "$NS_BROWSERS"

echo
if [ "$FAIL" -eq 0 ]; then echo "✓ $PASS passed"; else echo "✗ $FAIL failed, $PASS passed"; exit 1; fi
