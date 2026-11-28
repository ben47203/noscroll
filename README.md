<div align="center">

# noscroll

**A stubborn website and app blocker for macOS that's hard to switch off in the moment you want to cave.**

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
browsers, closes matching tabs within about two seconds of you looking at them,
quits blocked apps, and restarts itself if it's killed.

```console
$ noscroll block reddit.com instagram.com
Blocked reddit.com.
Blocked instagram.com.

$ noscroll limit youtube.com 30m
Limited youtube.com to 30m/day.

$ noscroll block app:Discord outside 9am-5pm weekdays
Downtime for app:discord: blocked outside 09:00–17:00 weekdays.

$ noscroll unblock reddit.com
Password to unblock:
Queued #1: Unblock reddit.com
Takes effect in 10m (Thu 26 Nov 13:10). Changed your mind? noscroll cancel 1
```

## Features

- 🧱 **Blocks properly.** It matches on the domain, so `reddit.com` covers
  `old.reddit.com` but `x.com` doesn't catch `netflix.com`. It also supports
  paths, exact hosts, keywords and allow-list exceptions.
- ⏳ **Daily time limits.** For example, 30 minutes of YouTube a day, counted
  only while the tab is in front. You get warnings at 5 minutes and 1 minute.
- 🌙 **Downtime.** Block a site or app on a schedule, such as `22:00-07:00`
  every night or `outside 9am-5pm weekdays`. It combines with a time limit.
- 🧩 **Apps too.** `app:Discord` works anywhere a site does. A blocked app is
  quit as soon as it's opened or brought to the front.
- 🔐 **Two unlock modes.** *Password* mode needs your password plus a cooldown.
  *Timer* mode has no password at all, just a long wait. A password is only as
  strong as your willpower to forget it, so timer mode skips it.
- 🆘 **A way back.** Forget your password and `noscroll forgot` gives you the
  machine back after a wait you choose (24 hours by default), with no password.
- 🕶️ **Discreet mode.** Prefix any command with `hex` and give the site
  hex-encoded. The names of the sites you block then never sit in plain text,
  in `list` or in your shell history.
- 🛡️ **Hard to break.**
  - A watchdog agent and the main agent restart each other.
  - State files are signed, made immutable and restored automatically if edited
    or deleted, even if the signing key is replaced.
  - A swapped or deleted binary is put back.
  - Any `noscroll` command repairs a broken install.
  - Upgrades go through the same queue.
- 🔋 **Light on battery.** One long-lived monitor checks the browser in front
  every 2s, and the ones in the background every 8s. Switching apps
  triggers a check at once. It measures about 1–1.5% of one CPU core (see
  [FAQ](#faq)).
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
2. sets your password (password mode only)
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
noscroll status                       # is it running? what's pending?
noscroll block reddit.com             # block a site and all its subdomains
noscroll block linkedin.com/feed      # block just the feed, not the rest of LinkedIn
noscroll limit youtube.com 45m        # 45 minutes a day
noscroll allow reddit.com/r/swift     # an exception (queued, because it loosens)
noscroll list                         # see your rules
noscroll check https://old.reddit.com/r/pics   # "would this be closed?"
```

## Guide

### Commands at a glance

Every restriction has an obvious inverse. Adding or tightening a restriction is
instant. Removing or loosening one goes through the [queue](#unlock-modes).

| Add | Remove | What it does |
| --- | --- | --- |
| `block <site>…` | `unblock <site>…` *(queued)* | close the site on sight |
| `block <site>… <from>-<to> [days]` | `unblock <site>…` *(queued)* | [downtime](#downtime): block on a schedule |
| `limit <site>… <time>` | `unlimit <site>…` *(queued)* | allow this much time per day |
| `allow <site>…` *(queued)* | `disallow <site>…` | an exception that beats any rule |

Any of these also accepts `'#n'` (a number from `noscroll list`) in place of a
site, and `app:Name` in place of a site (except `allow`). `unblock` only
removes blocks and downtime, and `unlimit` only removes limits. If you use the
wrong one, noscroll tells you which you need.

### Patterns

| Pattern | Matches |
| --- | --- |
| `reddit.com` | `reddit.com` and every subdomain (`www.`, `old.`, `m.`, …) |
| `reddit.com/r/all` | that path and anything below it, on any subdomain |
| `*.example.com` | subdomains only, not `example.com` itself |
| `=m.example.com` | exactly that host, nothing else |
| `~casino` | any URL containing the keyword |
| `app:Discord` | the app named `Discord.app` (case and spaces don't matter: `app:"Visual Studio Code"`) |

noscroll lower-cases patterns and strips the scheme, `www.` and trailing
slashes, so pasting a URL works: `noscroll block https://www.tiktok.com/`.

```sh
noscroll block <site> --grace 2m       # close only after 2 minutes on the page
noscroll import blocklist.txt          # one rule per line (e.g. from list --raw)
```

### Discreet mode (hex)

The sites you most want to block are often ones you'd rather not see written
down. Put `hex` in front of any rule command and give the site hex-encoded. It's
stored hex-encoded, masked in `noscroll list`, and the plain name never reaches
your shell history.

```sh
noscroll hex                                  # encode a site (hidden input) → prints hex
noscroll hex block 6578616d706c652e636f6d     # block it by hex
noscroll hex limit 6578616d706c652e636f6d 20m
noscroll hex unblock 6578616d706c652e636f6d
noscroll hex block                            # no site given: type it, hidden
noscroll config discreet on                   # hide everything, now and in future
```

```console
$ noscroll list
  #    SITE                                 TYPE     RULE
  1    reddit.com                           block
  2    •••••••• (hidden)                    block
  3    youtube.com                          limit    30m/day
  4    app:discord                          downtime blocked 22:00–07:00
```

Use `noscroll list --reveal` to see hidden rules. `noscroll hide all`,
`hide '#2'` and `unhide '#2'` change how existing rules are stored. Hex is about
discretion, not encryption: anyone who decodes it can read it.

### Time limits

```sh
noscroll limit youtube.com 30m         # new or lower: instant
noscroll limit youtube.com 1h          # higher: queued, because it loosens
noscroll block youtube.com             # back to a full block: instant
noscroll unlimit youtube.com           # remove the limit entirely: queued
noscroll usage                         # today's time on limited sites
```

Time counts only while a matching tab is the active tab and the browser is the
frontmost app (for an app, while it's the frontmost app). Time asleep or
suspended doesn't count, and the allowance resets at local midnight. When it
runs out, matching tabs close, or the app quits, for the rest of the day.

### Downtime

Downtime is a `block` with a schedule. Outside its hours the site or app works
normally (subject to any time limit); during them it's blocked.

```sh
noscroll block reddit.com 22:00-07:00                 # every night, past midnight
noscroll block app:Steam 9am-5pm weekdays             # during work hours
noscroll block x.com outside 8am-8pm                  # only allowed 8am–8pm
noscroll block youtube.com 9-17 weekdays 23-6         # several windows at once
noscroll limit youtube.com 30m                        # …plus 30 minutes a day outside them
noscroll unblock reddit.com                           # remove the downtime: queued
```

- **Times:** `22:00`, `2200`, `22`, `10pm`, `7:30am`. A window that ends before
  it starts runs past midnight and belongs to the day it starts on, so
  `22:00-07:00 fri` covers Friday night into Saturday morning.
- **Days** go after the time they apply to: `weekdays`, `weekends`, `daily`,
  `mon-fri`, `sat,sun`, `fri`. Without days, a window applies every day.
- **`outside A-B`** blocks everything except A–B on those days.
- **Changing it follows the usual rule.** Running `block` again with a schedule
  that covers every minute the old one did (or more) is instant. Shrinking it,
  or turning a full block into downtime, is queued.
- `noscroll check <url>` tells you whether downtime is on right now.

### Apps

Write `app:` and the app's name, as it appears in `/Applications`.

```sh
noscroll block app:Discord                  # quit it whenever it runs
noscroll block app:Steam 22:00-07:00        # downtime
noscroll limit app:"Visual Studio Code" 2h  # time while it's the frontmost app
```

A blocked app is quit when it comes to the front, and within two checks if it's
running in the background. It gets the same signal as a normal shutdown, so it
can save its state. Apps from the Mac App Store and elsewhere work the same way.

### Unlock modes

Pick one with `noscroll mode password|timer`. You can tune the three waits it
uses at any time:

| Wait | Default | Used for | Set with |
| --- | --- | --- | --- |
| **cooldown** | 10 min | every loosening change in *password* mode, after your password | `noscroll config cooldown 15m` |
| **timer** | 24 h | every loosening change in *timer* mode (no password) | `noscroll config timer 2d` |
| **recover** | 24 h | `noscroll forgot`: unlocking without your password | `noscroll config recover 48h` |

Making a wait longer is instant. Making one shorter is queued if it's the wait
currently protecting you (or `recover`). Changing mode is instant if the new
mode's wait is at least as long as the current one; otherwise it's queued. A
password is only as strong as your resolve not to type it, which is why timer
mode skips it.

These are queued: `unblock`, `unlimit`, `allow`, raising a `limit` or
`--grace`, `stop`, `uninstall`, upgrades, `config strict off`, shortening an
active wait, and switching to a mode with a shorter wait. Everything else
applies instantly.

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

Run `noscroll forgot`. After the **recover** wait (24 hours by default, and
never shorter than your cooldown), noscroll clears the password and stops
blocking. No password is needed. Then run `noscroll password` and
`noscroll start`. You can `noscroll cancel` it any time before then.

### Settings

```sh
noscroll config                        # show everything
noscroll config cooldown|timer|recover <time>
noscroll config discreet on|off        # hex-encode and mask every rule
noscroll config strict on|off          # quit browsers noscroll can't monitor or control
noscroll config notify on|off          # macOS notifications
noscroll config interval 3s            # check the front browser every 1–10s (default 2s)
```

Run `noscroll help` for the full command list, and `noscroll doctor` when
something looks wrong.

## How it works

```
 launchd (your user)
 ├── com.noscroll.agent            KeepAlive
 │     ├── monitor (one long-lived osascript, JavaScript)
 │     │     glance at the frontmost app every 0.5 s; read every tab of each
 │     │     running browser: every 2 s if a browser is in front, every 8 s if
 │     │     not, immediately when you switch apps
 │     └── for each check:
 │           1. apply queued changes whose delay has passed
 │           2. work out which downtime windows are on   (once a minute)
 │           3. quit blocked apps
 │           4. match every URL against your rules     (awk, only if tabs changed)
 │           5. close matches, count time on limited sites and apps
 │           6. restart the watchdog if it's gone
 │
 └── com.noscroll.agent.watchdog   every 30 s
       restart / re-enable the agent unless a legitimate stop is in force

 ~/.noscroll/
   sites · config · auth · binsum     immutable, HMAC-signed, signed backup
   pending · usage · stopped          HMAC-signed
```

- **Browsers are checked one at a time.** A browser that's missing, crashed or
  not yet permitted can't stop the others from being checked. If the monitor
  keeps failing, the agent falls back to direct polling for 10 minutes.
- **The queue is signed.** A hand-edited or back-dated request is thrown away,
  not obeyed.
- **The blocklist and settings are immutable** (`chflags uchg`) and signed. If
  they're edited outside noscroll, they're restored from a signed backup.
- **The agent remembers the last good state.** If `~/.noscroll` is deleted,
  or the signing key is replaced and edits are re-signed with the new one, the
  agent puts back the original key and rebuilds the files from memory.
- **The binary is checksummed.** If it's replaced or deleted, noscroll restores
  it from a signed spare copy.
- **Edited usage records count as used up:** that day's limits are spent.
- **Every command heals.** Running any `noscroll` command re-creates missing
  agents, clears launchd `disable` overrides and restarts what should be
  running.
- **It runs under a disguise.** The agent runs from a copy in `/tmp` named after
  a random system process, so it doesn't stand out in Activity Monitor.

### Threat model: what can still beat it

noscroll runs as **your** user, without root, so anything your account can do,
you can undo. It's built to make caving slow and deliberate, not impossible.
These are the bypasses that remain, even for someone who has read the source:

| Bypass | Why it works | Mitigation |
| --- | --- | --- |
| Booting out **both** agents in one command | Each agent restarts the other, but nothing restarts both. Any later `noscroll` command repairs them. | Root-owned LaunchDaemon (not yet built) |
| Turning noscroll off in **System Settings → Login Items** | macOS's background-item switch overrides launchd | Same |
| An unmonitored browser (Firefox, a Dock web app, a phone) | noscroll can only see scriptable browsers | `config strict on` quits known browsers it can't monitor |
| Revoking **Automation** permission | The agent can no longer read tabs | Strict mode quits a browser that refuses control |
| Killing the agent, then forging state before it restarts | A fresh agent has no memory to compare against | Needs the secret, the signature format and good timing |
| Setting the clock forward, or changing time zone during downtime | Waits and downtime use the system clock | Changing the clock or time zone needs an admin password |
| Renaming or copying an app bundle | App rules match the `.app` name | Block the copy too |
| Proxy and mirror sites (translate proxies, alternative frontends) | They're different domains | Block them too, or use `~keyword` rules |

For a lock you can't pick yourself, have someone else hold the admin password,
or use Screen Time with a passcode set by someone else. noscroll isn't
parental-control software or spyware, and it doesn't hide from the person who
installed it.

## Troubleshooting

<details>
<summary><b>A browser isn't being blocked</b></summary>

Run `noscroll doctor`. Usually macOS hasn't given noscroll permission to
control that browser:

1. Open **System Settings → Privacy & Security → Automation**.
2. Find **bash** or **osascript** and turn on the browser.
3. If nothing's listed, run `tccutil reset AppleEvents`, then open the browser.
   The prompt will appear again.

With `config strict on`, a browser that refuses control is quit until you
allow it. Major macOS updates sometimes reset these permissions, and that's the most
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

**Upgrading?** Run `./install.sh`. From v1, your blocklist, grace periods and
password migrate automatically, and the old agent is replaced. From 2.0,
`delay`/`recovery_delay` become `cooldown`/`timer`/`recover`, and recovery
codes are removed. v1 matched
anywhere in the URL. v2 matches domains, so v1 entries that weren't domains
become `~keyword` rules and keep working as before.

**Why bash?** It ships with every Mac, there's nothing to compile or install,
and the whole program is one file you can read before you trust it.

**How much battery does it use?** Measured on an Apple Silicon Mac with
Safari open (9 tabs), over two minutes including start-up:

| Version | CPU (share of one core) |
| --- | --- |
| 2.1 (started `osascript` every 2 s, one Apple Event per tab) | 10.2% |
| 2.2 (persistent monitor, bulk reads, adaptive rate) | ≈1–1.5% |

Safari also does work answering each check: about 7ms per check now, against
43ms before. Most of the remaining cost is talking to the browser, so
`config interval 4s` roughly halves it, at the price of a slower close.

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
