# Changelog

All notable changes to noscroll. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [semantic versioning](https://semver.org/).

## [Unreleased]

### Changed
- The agent runs as `noscroll` from its install location instead of a copy
  in `/tmp` named after a random system process. The disguise didn't stop
  anyone who knew it was there, and it looks like malware to security tools.

## [2.2.0] - 2026-11-28

### Added
- **Downtime:** `noscroll block <site> 22:00-07:00 [days]` blocks on a
  schedule. Supports overnight windows, `outside 9am-5pm`, several windows,
  and days (`weekdays`, `weekends`, `mon-fri`, `sat,sun`). It combines with a
  time limit. Widening a schedule is instant; shrinking one is queued.
- **App rules:** `app:Discord` works with `block`, downtime and `limit`.
  Blocked apps are quit; limited apps count time while they're in front.
- `config interval <1–10s>`. Raising it is queued like any other loosening.

### Changed
- **About 7× less CPU** (10.2% → ≈1.5% of one core, measured). A single
  long-lived JavaScript-for-Automation monitor replaces starting `osascript`
  every 2 seconds. It reads all of a browser's URLs in three Apple Events
  instead of one per tab, and it checks adaptively: every interval while a
  browser is in front, 4× less often otherwise, and immediately when you
  switch to a browser.
- Config is read with shell builtins, the matcher re-runs only when tabs
  change, and full signature checks run only when a state file changes.
- The monitor checks straight away on any app switch, not just to a browser.
- `check` lists every rule that hits a URL, and whether its downtime is on.

### Fixed
- The daemon silenced its own stderr after the first monitor restart.

## [2.1.0] - 2026-11-26

### Changed (breaking CLI)
- Commands now come in obvious pairs: `block`/`unblock`, `limit`/`unlimit`,
  `allow`/`disallow`. `add`, `remove` and `limit … off` are gone.
- Hex input is now a prefix: `noscroll hex block <hex>`. Plain `noscroll hex`
  encodes a site. `--hex`, `--prompt`, `--hide` and `encode` are gone.
- `setup-password` is now `password`.
- The waits are named and set independently: `config cooldown`,
  `config timer` and `config recover`. `mode` no longer takes `--delay`.
  Existing `delay`/`recovery_delay` settings migrate automatically.

### Removed
- Recovery codes. A second secret is no stronger than the password, and
  `forgot` already covers a lost password.

### Security
- A swapped or deleted binary is restored from a signed spare copy.
- The agent rebuilds deleted state from memory and undoes edits re-signed
  with a replaced signing key.
- Strict mode quits browsers whose Automation permission was revoked.

## [2.0.0] - 2026-11-26

### Fixed
- **Safari stopped being blocked** on Macs without Google Chrome. Both
  browsers were compiled into one AppleScript, so a missing Chrome
  dictionary made the whole check fail silently. Each browser is now
  checked separately and errors are logged.

### Added
- Domain-aware matching: subdomains, paths with boundaries, `*.sub-only`,
  `=exact`, `~keyword`, and `!allow` exceptions.
- Discreet mode: hex-encoded rules (`--hex`, `--prompt`, `--hide`,
  `hide`/`unhide`, `config discreet on`).
- Daily time limits (`limit`, `--limit`, `usage`) with notifications.
- Unlock modes: password + cooldown, or timer (no password, long delay).
- Queue for every loosening change, with `pending` and `cancel`.
- Recovery codes and `forgot` (unlocks after 24 h without a password).
- `stop --for` timed pauses.
- Watchdog agent, signed state with automatic restore, immutable files,
  self-healing CLI, and upgrades that go through the queue.
- Support for Safari Technology Preview, Chrome Beta/Dev/Canary,
  Chromium, Brave, Edge, Vivaldi and Arc. Strict mode quits browsers that
  can't be monitored.
- `doctor`, `check`, `import`, `encode`, `config`.
- One-line `curl | bash` installer, test suite and CI.

### Changed
- State moved from `~/.noscroll_*` to `~/.noscroll/` (migrated automatically).
- Passwords are prompted for and never passed as arguments.

## [1.0.0] - 2026-06-23

- First release: Chrome and Safari tab blocker with a password, a
  10-minute cooldown and a disguised LaunchAgent.

[2.2.0]: https://github.com/ben47203/noscroll/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/ben47203/noscroll/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/ben47203/noscroll/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/ben47203/noscroll/releases/tag/v1.0.0
