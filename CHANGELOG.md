# Changelog

All notable changes to noscroll. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [semantic versioning](https://semver.org/).

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

[2.1.0]: https://github.com/ben47203/noscroll/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/ben47203/noscroll/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/ben47203/noscroll/releases/tag/v1.0.0
