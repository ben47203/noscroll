#!/bin/bash
# shellcheck disable=SC2034,SC2153  # globals are read by the sourced noscroll functions
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
ff() { lock; sbody "$F_PENDING" | awk -F'|' -v OFS='|' '{ $2 = 0; print }' | swrite "$F_PENDING"; unlock; process_pending; }
printf 'hunter22\nhunter22\n' | run password | grep -q "Password set" && ok || fail "password"

run install >/dev/null
[ -f "$NOSCROLL_APP_DIR/noscroll" ] && ok || fail "binary installed"
[ -L "$NOSCROLL_LINK" ] && ok || fail "command symlinked"
[ -f "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.plist" ] && ok || fail "agent plist"
[ -f "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.watchdog.plist" ] && ok || fail "watchdog plist"
plutil -lint "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.plist" >/dev/null && ok || fail "agent plist is valid"
plutil -lint "$NOSCROLL_AGENTS_DIR/$NOSCROLL_LABEL.watchdog.plist" >/dev/null && ok || fail "watchdog plist is valid"
run list | grep -q "instagram.com" && ok || fail "default sites seeded"
run add x.com | grep -q "now 'block'" && ok || fail "old command names point at the new ones"

# block / hex
run block news.ycombinator.com lobste.rs >/dev/null
run list --raw | grep -qx "news.ycombinator.com" && ok || fail "block is immediate"
run list --raw | grep -qx "lobste.rs" && ok || fail "block takes several sites"
run hex block "$(hex_encode hidden.example.com)" >/dev/null
run list --raw | grep -qx "hex:$(hex_encode hidden.example.com)" && ok || fail "hex block stores hex"
run list | grep -q "hidden.example.com" && fail "hidden site shown in list" || ok
run list --reveal | grep -q "hidden.example.com" && ok || fail "list --reveal"
printf 'prompted.example.com\n' | run hex block >/dev/null
run list --raw | grep -qx "hex:$(hex_encode prompted.example.com)" && ok || fail "hex block with no site prompts"
run hex block reddit.com | grep -q "isn't hex" && ok || fail "hex block rejects plain names"
eq "hex encoder" "$(printf 'Example.com\n' | "$NS" hex 2>/dev/null)" "$(hex_encode example.com)"
run hex check "$(hex_encode https://hidden.example.com/x)" | grep -q "Blocked by rule" && ok || fail "hex check"

# limit: new or lower = instant; on a blocked site or higher = queued
run limit youtube.com 30m <<< "hunter22" | grep -q "Queued" && ok || fail "limit on a blocked site is queued"
run list --raw | grep -qx "youtube.com" && ok || fail "…and not applied yet"
run cancel all >/dev/null
[ -z "$(pending_lines)" ] && ok || fail "cancel all"
run limit newsite.com other.com 20m >/dev/null
run list --raw | grep -qx "newsite.com limit=1200" && ok || fail "limit on a new site is immediate"
run list --raw | grep -qx "other.com limit=1200" && ok || fail "limit takes several sites"
run limit newsite.com 10m >/dev/null
run list --raw | grep -qx "newsite.com limit=600" && ok || fail "lowering a limit is immediate"
run limit newsite.com 1h <<< "hunter22" | grep -q "Queued" && ok || fail "raising a limit is queued"
run cancel all >/dev/null
run limit newsite.com | grep -q "usage" && ok || fail "limit needs a duration"
run list | grep -E '^ +[0-9]+ +newsite.com' | grep -q ' limit ' && ok || fail "list shows limit type"

# unblock / unlimit only touch their own kind
run unlimit lobste.rs 2>&1 | grep -q "use: noscroll unblock" && ok || fail "unlimit on a block points at unblock"
run unblock newsite.com 2>&1 | grep -q "use: noscroll unlimit" && ok || fail "unblock on a limit points at unlimit"
run unblock reddit.com <<< "nope" | grep -q "Wrong password" && ok || fail "wrong password rejected"
run unblock reddit.com x.com <<< "hunter22" | grep -c "Queued #" | grep -qx 2 && ok || fail "unblock queues each site, one password"
run unlimit newsite.com <<< "hunter22" | grep -q "Queued #" && ok || fail "unlimit is queued"
run list --raw | grep -qx "reddit.com" && ok || fail "unblock not applied before the wait"
ff
run list --raw | grep -qx "reddit.com" && fail "unblock applied after the wait" || ok
run list --raw | grep -q "^newsite.com" && fail "unlimit applied after the wait" || ok

# Hand-edited queue is discarded, not obeyed.
run unblock instagram.com <<< "hunter22" >/dev/null
chflags nouchg "$F_PENDING" 2>/dev/null
sed -i '' 's/^\([0-9]*\)|[0-9]*|/\1|0|/' "$F_PENDING"
process_pending
run list --raw | grep -qx "instagram.com" && ok || fail "forged queue entry ignored"

# Tampering with the blocklist is reverted.
chflags nouchg "$F_SITES"; printf 'oops\n' > "$F_SITES"
run list --raw 2>/dev/null | grep -qx "instagram.com" && ok || fail "tampered blocklist restored"

# allow is queued; disallow is instant.
run allow reddit.com/r/swift <<< "hunter22" | grep -q "Queued" && ok || fail "allow is queued"
apply_action upsert "!reddit.com/r/swift"
run disallow reddit.com/r/swift | grep -q "Disallowed" && ok || fail "disallow is instant"
run list --raw | grep -q '^!' && fail "disallow removed the exception" || ok

# Hide / unhide.
run hide all >/dev/null
run list --raw | grep -vq '^hex:' && fail "hide all left plain rules" || ok
run unhide '#1' >/dev/null
run list --raw | head -1 | grep -q '^hex:' && fail "unhide #1" || ok

# check
run check https://www.instagram.com/reels | grep -q "Blocked by rule" && ok || fail "check blocked"
run check https://example.com | grep -q "Allowed" && ok || fail "check allowed"

# Lengths: longer is instant; shortening the active wait is queued.
run config cooldown 20m | grep -q "cooldown: 20m" && ok || fail "longer cooldown is instant"
run config cooldown 5m <<< "hunter22" | grep -q "Queued" && ok || fail "shorter active cooldown is queued"
run cancel all >/dev/null
run config timer 2h | grep -q "timer: 2h" && ok || fail "inactive timer can be shortened instantly"
run config recover 30m | grep -q "at least 1h" && ok || fail "recover has a minimum"
run config recover 2d | grep -q "recover: 2d" && ok || fail "longer recover is instant"

# Timer mode: no password, every loosening waits the timer.
run mode timer | grep -q "Mode: timer" && ok || fail "switch to a longer wait is instant"
apply_action config "mode=timer"
eq "timer mode" "$(cfg mode)" timer
run stop </dev/null | grep -q "Takes effect in 2h" && ok || fail "timer stop waits the timer, no password"
run forgot | grep -q "timer mode" && ok || fail "forgot explains timer mode"
run cancel all >/dev/null
run mode password | grep -q "Queued" && ok || fail "switch to a shorter wait is queued"
run cancel all >/dev/null

# Forgot password (password mode) waits the recover length.
apply_action config "mode=password"
run forgot </dev/null | grep -q "Takes effect in 2d" && ok || fail "forgot waits recover"
run pending | grep -q "Forgotten password" && ok || fail "recovery is pending"
ff
has_password && fail "recovery cleared the password" || ok
is_stopped && ok || fail "recovery stopped the blocker"

# While stopped, changes apply immediately.
run unblock instagram.com | grep -q "Done" && ok || fail "stopped: unblock is immediate"
run start >/dev/null
is_stopped && fail "start clears stop" || ok

# v2.0 config keys migrate.
printf 'mode=timer\ndelay=7200\nrecovery_delay=90000\n' | swrite "$F_CONFIG" protect
printf 'x\n' | swrite "$F_RECOVERY_OLD" protect
migrate_config
eq "delay → timer" "$(cfg timer)" 7200
eq "recovery_delay → recover" "$(cfg recover)" 90000
[ -f "$F_RECOVERY_OLD" ] && fail "old recovery code removed" || ok

# Binary swapped or deleted → restored from the signed copy.
chflags nouchg "$NOSCROLL_APP_DIR/noscroll"; printf '#!/bin/bash\nexit 0\n' > "$NOSCROLL_APP_DIR/noscroll"
run status >/dev/null
cmp -s "$NOSCROLL_APP_DIR/noscroll" "$NS" && ok || fail "swapped binary restored"
chflags nouchg "$NOSCROLL_APP_DIR/noscroll"; rm -f "$NOSCROLL_APP_DIR/noscroll"
run status >/dev/null
cmp -s "$NOSCROLL_APP_DIR/noscroll" "$NS" && ok || fail "deleted binary restored"

# Daemon memory guard: deleted state and re-signed forgeries are undone.
(
  NS_DAEMON=1; G_SECRET=""; G_SITES=""; G_CONFIG=""; G_AUTH=""; G_BINSUM=""
  guard_state
  before=$(sbody "$F_SITES")
  chflags -R nouchg "$NOSCROLL_HOME"; rm -rf "$NOSCROLL_HOME"
  guard_state
  [ "$(sbody "$F_SITES")" = "$before" ] && sverify "$F_SITES" && sverify "$F_CONFIG" && echo DELETED_OK
  # Forge: new secret, edited blocklist re-signed with it.
  chflags nouchg "$F_SECRET"; chmod 600 "$F_SECRET"; openssl rand -hex 32 > "$F_SECRET"
  printf 'nothing.example\n' | swrite "$F_SITES" protect
  guard_state
  [ "$(sbody "$F_SITES")" = "$before" ] && echo FORGED_OK
) > "$SANDBOX/guard.out" 2>&1
grep -q DELETED_OK "$SANDBOX/guard.out" && ok || fail "guard rebuilds a deleted state dir"
grep -q FORGED_OK "$SANDBOX/guard.out" && ok || fail "guard undoes a re-signed forgery"

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

# The persistent JXA monitor runs and ends each check with a TICK line.
MON_OUT=$(osascript -l JavaScript -e "$NS_MONITOR_JS" 0.01 2 "Nope|com.example.not-installed|safari" 2>&1)
eq "monitor ticks" "$(printf '%s\n' "$MON_OUT" | grep -c '^TICK')" 2
printf '%s\n' "$MON_OUT" | grep -q $'^TICK\t.*\t0$' && ok || fail "monitor: absent browser reported as not running ($MON_OUT)"

echo
if [ "$FAIL" -eq 0 ]; then echo "✓ $PASS passed"; else echo "✗ $FAIL failed, $PASS passed"; exit 1; fi
