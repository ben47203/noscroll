# noscroll

A stubborn website blocker for macOS. It watches Chrome and Safari and closes
tabs for sites you've told it to block — and it's deliberately hard to turn off
in the moment you want to cave.

Most blockers fail because disabling them takes one click. `noscroll` is a
**commitment device**: stopping it requires a password *and* a 10-minute
cooldown, it reinstalls itself if you kill it, and it hides in `ps` under a
random system-process name. The friction is the feature.

> ⚠️ This is a personal-discipline tool for blocking **your own** browsing on
> **your own** machine. It is not spyware or a parental-control product, and it
> makes no attempt to be tamper-proof against a determined admin user. The real
> lock is the password + cooldown plus your own intent.

## How it works

- A `bash` loop polls Chrome and Safari every 2 seconds via AppleScript and
  closes any tab whose URL matches an entry in your blocklist.
- It runs as a **LaunchAgent** with `KeepAlive`, so quitting the process just
  makes `launchd` respawn it. The plist is flagged immutable (`chflags uchg`).
- `stop` and `uninstall` require a password (salted SHA-256 hash) and `stop`
  imposes a **10-minute cooldown** before the blocker actually exits.
- On launch the process copies itself to `/tmp` under a random system binary's
  name so a casual `ps` / Activity Monitor scan doesn't flag it.

## Requirements

- macOS (uses AppleScript to drive Chrome/Safari)
- You'll be asked to grant **Automation** and **Accessibility** permissions the
  first time it controls a browser (System Settings → Privacy & Security).

## Install

```sh
git clone https://github.com/ben47203/noscroll.git
cd noscroll
./install.sh
```

The installer copies `noscroll` to `~/.local/bin`, prompts you to set a
password, and registers the LaunchAgent. Make sure `~/.local/bin` is on your
`PATH`.

Prefer to do it by hand?

```sh
install -m 755 noscroll ~/.local/bin/noscroll
noscroll setup-password
noscroll install
```

## Usage

```
noscroll <command>
```

### Blocking

| Command | What it does |
| --- | --- |
| `noscroll add <site>` | Add a site to the blocklist (no password) |
| `noscroll add <site>:<secs>` | Add with a grace period (see below) |
| `noscroll remove <site> [pass]` | Remove a site (**password required**) |
| `noscroll list` | Show all blocked sites |

Matching is a simple substring check against the tab URL, so `instagram.com`
blocks the whole site while `linkedin.com/feed` blocks only the feed.

**Grace periods.** Append `:<seconds>` to only close a tab once it has matched
*continuously* for that long — handy for sites you sometimes need briefly:

```sh
noscroll add "linkedin.com/feed:60"   # close the feed after 60s on it
```

### Control

| Command | What it does |
| --- | --- |
| `noscroll status` | Running state, any pending-stop countdown, blocked sites |
| `noscroll stop [pass]` | Schedule a stop — **password required**, takes effect after a 10-min cooldown |
| `noscroll cancel-stop` | Cancel a pending stop (no password) |
| `noscroll start` | Re-enable after a stop |

### Setup

| Command | What it does |
| --- | --- |
| `noscroll install` | Register the LaunchAgent (survives reboots and kills) |
| `noscroll uninstall [pass]` | Remove the LaunchAgent — **password required** |
| `noscroll setup-password` | Set or change the password |

## Files

`noscroll` keeps its state in your home directory (all git-ignored):

| File | Purpose |
| --- | --- |
| `~/.noscroll_sites` | Your blocklist (read-only; use `add`/`remove`) |
| `~/.noscroll_hash` | Salted password hash |
| `~/.noscroll_cooldown` | Timestamp of a pending stop |
| `~/.noscroll_timers` | Grace-period bookkeeping |
| `~/Library/LaunchAgents/com.noscroll.agent.plist` | The LaunchAgent |

The repo ships **without a blocklist** — the first run seeds a small default
set (Instagram, YouTube, X/Twitter, Reddit, TikTok) which you then edit with
`add`/`remove`. Your personal list never leaves your machine.

## Uninstall

```sh
./uninstall.sh        # or: noscroll uninstall && rm ~/.local/bin/noscroll
```

Requires your password, and respects the cooldown. That's the point.

## License

MIT — see [LICENSE](LICENSE).
