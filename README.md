<div align="center">

# noscroll

**A stubborn website blocker for macOS that's hard to switch off in the moment you want to cave.**

[![CI](https://github.com/ben47203/noscroll/actions/workflows/ci.yml/badge.svg)](https://github.com/ben47203/noscroll/actions/workflows/ci.yml)
![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Shell](https://img.shields.io/badge/pure-bash-4EAA25?logo=gnubash&logoColor=white)
[![License: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

[Install](#install) · [Quick start](#quick-start) · [Guide](#guide) · [How it works](#how-it-works) · [FAQ](#faq)

</div>

---

Most blockers fail because turning them off takes one click. With **noscroll**,
every change that *loosens* it (unblocking a site, raising a limit, stopping
it) goes into a queue and waits. You choose what the wait needs: a password and
a 10-minute cooldown, or no password and a 24-hour delay. Changes that
*tighten* it apply straight away.

It's one dependency-free bash script. It watches Safari and Chromium-based
browsers, closes matching tabs within about two seconds, and restarts itself if
it's killed.

```console
$ noscroll add reddit.com instagram.com
Blocked reddit.com.
Blocked instagram.com.

$ noscroll limit youtube.com 30m
Blocked youtube.com (30m/day).

$ noscroll remove reddit.com
Password (or recovery code) to unblock:
Queued #1: Unblock reddit.com
Takes effect in 10m (Thu 26 Nov 13:10). Changed your mind? noscroll cancel 1
```

## Features

- 🧱 **Blocks properly.** It matches on the domain, so `reddit.com` covers
  `old.reddit.com` but `x.com` doesn't catch `netflix.com`. It also supports
  paths, exact hosts, keywords and allow-list exceptions.
- ⏳ **Daily time limits.** For example, 30 minutes of YouTube a day, counted
  only while the tab is in front. You get warnings at 5 minutes and 1 minute.
- 🔐 **Two unlock modes.** *Password* mode needs your password plus a cooldown.
  *Timer* mode has no password at all, just a long wait. A password is only as
  strong as your willpower to forget it, so timer mode skips it.
- 🆘 **Built-in recovery.** You get a recovery code, and `noscroll forgot` gives
  you the machine back after 24 hours, with no password needed.
- 🕶️ **Discreet mode.** Rules can be stored hex-encoded and masked in `list`, so
  the names of the sites you block don't sit in plain text or in your shell
  history.
- 🛡️ **Hard to break.**
  - A watchdog agent and the main agent restart each other.
  - State files are signed, made immutable and restored automatically if edited.
  - Any `noscroll` command repairs a broken install.
  - Upgrades go through the same queue.
- 🌐 **Multi-browser.** Safari, Safari Technology Preview, Chrome
  (incl. Beta/Dev/Canary), Chromium, Brave, Edge, Vivaldi and Arc. Strict mode
  quits browsers it can't monitor, such as Firefox.

## Install

**Requirements:** macOS 13 or later. Nothing else: noscroll uses the bash,
`osascript` and `openssl` that ship with macOS.

```sh
curl -fsSL https://raw.githubusercontent.com/ben47203/noscroll/main/install.sh | bash
```

Or from a clone:

```sh
git clone https://github.com/ben47203/noscroll.git
cd noscroll
./install.sh
```

The installer:

1. asks how unlocking should work (**password** or **timer**, see [Unlock modes](#unlock-modes))
2. sets your password and prints a **recovery code**. Store it somewhere you
   can't reach on impulse; giving it to a friend works well.
3. copies noscroll to `~/Library/Application Support/noscroll/` and links it as
   `~/.local/bin/noscroll`
4. starts the login agent and its watchdog

> [!IMPORTANT]
> The first time noscroll checks a browser, macOS asks whether it may control
> that browser. Click **Allow**. If you miss the prompt, see
> [Troubleshooting](#troubleshooting).

If `~/.local/bin` isn't on your `PATH`, add this to `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Quick start

```sh
noscroll status                      # is it running? what's pending?
noscroll add reddit.com              # block a site and all its subdomains
noscroll add linkedin.com/feed       # block just the feed, not the rest of LinkedIn
noscroll limit youtube.com 45m       # 45 minutes a day
noscroll allow reddit.com/r/swift    # an exception (queued, because it loosens)
noscroll list                        # see your rules
noscroll check https://old.reddit.com/r/pics   # "would this be closed?"
```

## Guide

### Blocking sites

| Pattern | Blocks |
| --- | --- |
| `reddit.com` | `reddit.com` and every subdomain (`www.`, `old.`, `m.`, …) |
| `reddit.com/r/all` | that path and anything below it, on any subdomain |
| `*.example.com` | subdomains only, not `example.com` itself |
| `=m.example.com` | exactly that host, nothing else |
| `~casino` | any URL containing the keyword |
| `!reddit.com/r/swift` | *exception*: never closed, even if a block rule matches |

When you add a pattern, noscroll lower-cases it and strips the scheme, `www.`
and trailing slashes, so pasting a URL works: `noscroll add https://www.tiktok.com/`.

```sh
noscroll add <site>…                    # block (instant)
noscroll add <site> --grace 2m          # close only after 2 minutes on the page
noscroll add <site> --limit 30m         # daily allowance instead of a hard block
noscroll remove <site>                  # unblock (queued)
noscroll remove '#3'                    # by number from `noscroll list`
noscroll import blocklist.txt           # one rule per line
```

### Discreet mode (hex-encoded sites)

The sites you most want to block are often ones you'd rather not see listed.
noscroll can store any rule hex-encoded, so the name never appears in the
blocklist, in `noscroll list` or in your shell history.

```sh
noscroll add --prompt                   # type the site with hidden input
noscroll add --hex 6578616d706c652e636f6d
noscroll add example.com --hide         # hide one rule
noscroll config discreet on             # hide everything, now and in future
noscroll encode                         # print the hex for a site (hidden input)
```

```console
$ noscroll list
  #    SITE                                 TYPE   RULE
  1    reddit.com                           block
  2    •••••••• (hidden)                    block
  3    youtube.com                          block  30m/day
```

Use `noscroll list --reveal` to see hidden rules, or `noscroll unhide '#2'` /
`noscroll hide all` to change how they're stored. Hex is about discretion, not
encryption: anyone who decodes it can read it.

### Time limits

```sh
noscroll limit youtube.com 30m          # set (or lower: instant)
noscroll limit youtube.com 1h           # raise: queued, because it loosens
noscroll limit youtube.com off          # back to a full block (instant)
noscroll usage                          # today's time on limited sites
```

Time counts only while a matching tab is the active tab and the browser is the
frontmost app. Time asleep or suspended doesn't count, and the allowance resets
at local midnight. When it runs out, matching tabs close for the rest of the day.

### Unlock modes

| | **Password** (default) | **Timer** |
| --- | --- | --- |
| To loosen anything | password, then wait **10 min** | no password, wait **24 h** |
| Delay | `--delay`, min 1 min | `--delay`, min 1 min |
| Lost your password? | recovery code, or `noscroll forgot` (24 h) | nothing to lose |
| Best for | casual friction | serious commitment |

```sh
noscroll mode                           # show the current mode
noscroll mode timer --delay 24h         # switch (queued, since it changes the rules)
noscroll mode password --delay 15m
```

These all go through the queue: `remove`, `allow`, raising a `limit` or
`--grace`, `stop`, `uninstall`, upgrades, `config strict off`, shortening the
recovery delay and changing mode. Everything else applies instantly.

### Stopping, pausing and the queue

```sh
noscroll stop                # stop blocking (after the delay)
noscroll stop --for 2h       # pause, then start again automatically
noscroll start               # start again after a stop
noscroll pending             # what's queued and when it lands
noscroll cancel 3            # cancel one queued change (no password needed)
noscroll cancel all          # …or all of them
```

Cancelling never needs a password. The urge often passes before the delay does.

### Forgot your password?

1. **Have your recovery code?** Use it anywhere noscroll asks for your password.
2. **Lost both?** Run `noscroll forgot`. After 24 hours (or your delay, if
   that's longer), noscroll clears the password and stops blocking, with no
   password needed. Then run `noscroll setup-password` and `noscroll start`.

### Settings

```sh
noscroll config                          # show all settings
noscroll config discreet on|off          # hex-encode and mask new rules
noscroll config strict on|off            # quit browsers noscroll can't monitor
noscroll config notify on|off            # macOS notifications
noscroll config recovery-delay 48h       # how long `forgot` takes (min 1h)
```

### All commands

Run `noscroll help` for the full list. The one you'll reach for when something
looks wrong is `noscroll doctor`.

## How it works

```
 launchd (your user)
 ├── com.noscroll.agent            KeepAlive · every 2 s
 │     1. apply queued changes whose delay has passed
 │     2. ask each running browser for its tabs   (AppleScript, one per browser)
 │     3. match every URL against your rules      (awk)
 │     4. close matches, count time on limited sites
 │     5. restart the watchdog if it's gone
 │
 └── com.noscroll.agent.watchdog   every 30 s
       restart / re-enable the agent unless a legitimate stop is in force

 ~/.noscroll/
   sites · config · auth · recovery   immutable, HMAC-signed, signed backup
   pending · usage · stopped          HMAC-signed
```

- **Browsers are checked one at a time.** A browser that's missing, crashed or
  not yet permitted can't stop the others from being checked.
- **The queue is signed.** A hand-edited or back-dated request is thrown away,
  not obeyed.
- **The blocklist and settings are immutable** (`chflags uchg`) and signed. If
  they're edited outside noscroll, they're restored from a signed backup.
- **Edited usage records count as used up:** that day's limits are spent.
- **Every command heals.** Running any `noscroll` command re-creates missing
  agents, clears launchd `disable` overrides and restarts what should be
  running.
- **It runs under a disguise.** The agent runs from a copy in `/tmp` named after
  a random system process, so it doesn't stand out in Activity Monitor.

### What it is not

noscroll is a **commitment device** for blocking *your own* browsing on *your
own* Mac. It runs as your user, without root. Someone who's determined, has
admin rights and has read this source can always remove it. The aim is to make
caving slow and deliberate, not impossible. It isn't parental-control software
or spyware, and it doesn't hide from the person who installed it.

## Troubleshooting

<details>
<summary><b>A browser isn't being blocked</b></summary>

Run `noscroll doctor`. Usually macOS hasn't given noscroll permission to
control that browser:

1. Open **System Settings → Privacy & Security → Automation**.
2. Find **bash** or **osascript** and turn on the browser.
3. If nothing's listed, run `tccutil reset AppleEvents`, then open the browser.
   The prompt will appear again.

Major macOS updates sometimes reset these permissions, and that's the most
common reason blocking stops after an update. Also check **System Settings →
General → Login Items** and make sure background items aren't turned off for
`bash`/noscroll.
</details>

<details>
<summary><b>Firefox / Zen / Opera / Orion</b></summary>

These browsers don't let other apps read their tabs through AppleScript, so
noscroll can't see them. Turn on `noscroll config strict on` to quit them
whenever they open.
</details>

<details>
<summary><b>Private windows, web apps and other gaps</b></summary>

Private windows are normally visible to AppleScript and are checked like any
other window. Check yours by opening a blocked site in one: `noscroll doctor`
lists the tab count each browser reports. Web apps added to the Dock (Safari's
*Add to Dock*, Chrome's *Install app*) run as separate apps that can't be
scripted, so they aren't checked.
</details>

<details>
<summary><b>Upgrading</b></summary>

Run the installer again. On a running install, the upgrade waits in the queue
like any other change. Otherwise you could swap in a weaker script.
</details>

## Uninstall

```sh
noscroll uninstall        # or ./uninstall.sh
```

This goes through the same rules as everything else (password and/or delay).
When it completes, it removes the agents, the binary, the `noscroll` link and
`~/.noscroll`. To keep your rules, run `noscroll list --raw > my-rules.txt`
first; `noscroll import my-rules.txt` restores them later.

## FAQ

**Upgrading from v1?** Run `./install.sh`. Your blocklist, grace periods and
password migrate automatically, and the old agent is replaced. v1 matched
anywhere in the URL. v2 matches domains, so v1 entries that weren't domains
become `~keyword` rules and keep working as before.

**Why bash?** It ships with every Mac, there's nothing to compile or install,
and the whole program is one file you can read before you trust it.

**Does it phone home?** No. It makes no network requests at all. Your blocklist
never leaves your machine.

## Contributing

Issues and PRs are welcome. Work on a feature branch off `dev`. Before opening
a PR, run:

```sh
shellcheck noscroll install.sh uninstall.sh tests/run.sh
./tests/run.sh
```

The test suite runs in a temporary sandbox. It never touches your real install,
launchd or browsers. `main` holds tagged releases; `dev` is where features land.

## Licence

[MIT](LICENSE)
