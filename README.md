# codex-account

Switch between multiple Codex accounts without signing out.

[![CI](https://github.com/fernandostrive/codex-account/actions/workflows/ci.yml/badge.svg)](https://github.com/fernandostrive/codex-account/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## The problem

Codex keeps its credentials in a single file, `~/.codex/auth.json`. Signing out
through the app doesn't just delete that file — it revokes the tokens on
OpenAI's servers, which also invalidates the browser session behind them.

So if you have a work account and a personal account, every switch costs a full
sign-in: open the app, log out, open the browser, authenticate again.

`codex-account` never revokes anything. It saves each account's credential file
under a name and swaps them in and out, so both accounts stay signed in and
switching takes a second.

```console
$ codex-account save work
Saved 'work' (you@company.com).

$ codex-account list
* work                 you@company.com
  personal             you@gmail.com

$ codex-account use personal
Quitting Codex...
Codex stopped.
Updated profile 'work' with the current tokens.
Switched to 'personal' (you@gmail.com).
Codex reopened.
```

## Install

Requires `bash` (3.2+, so macOS's built-in shell works), plus `pgrep`. `jq` is
used when present but is not required.

**Homebrew** — not yet published. For now:

```sh
git clone https://github.com/fernandostrive/codex-account.git
cd codex-account
sudo make install            # installs to /usr/local/bin
```

Or without root:

```sh
make install PREFIX="$HOME/.local"
```

Or just drop the single file anywhere on your `PATH`:

```sh
curl -fsSLo ~/.local/bin/codex-account \
  https://raw.githubusercontent.com/fernandostrive/codex-account/main/bin/codex-account
chmod +x ~/.local/bin/codex-account
```

It's one self-contained script with no dependencies to install. Read it before
you run it — it handles your credentials.

## Usage

| Command | What it does |
| --- | --- |
| `codex-account list` | List saved profiles; `*` marks the active one |
| `codex-account current` | Show which account is signed in right now |
| `codex-account save <name>` | Save the active sign-in under a name |
| `codex-account use <name>` | Switch to a saved profile |
| `codex-account forget` | Sign out locally, leaving the server session alive |
| `codex-account remove <name>` | Delete a saved profile |

Options: `--dry-run`, `--force`, `--no-reopen`, `--discard-orphan`, `--quiet`.

### Getting started

1. Sign in to Codex as your first account, then `codex-account save work`.
2. `codex-account forget` — signs you out locally without revoking anything.
3. Sign in as your second account, then `codex-account save personal`.
4. From now on, `codex-account use work` / `use personal`.

Step 2 matters: if you use the app's own **Log out** button, you revoke the
session you just saved and the profile becomes useless.

## How it works

On `use`, the tool:

1. Refuses to run if it was started from a terminal *inside* Codex, since
   quitting the app would kill it mid-write.
2. Quits Codex and waits for it to actually exit. If it doesn't, nothing is
   touched.
3. Writes the live credential back to its own profile, so refreshed tokens
   aren't lost.
4. Installs the requested profile via a temp file and an atomic rename.
5. Reopens Codex.

At no point does it contact OpenAI, call `codex logout`, or touch your browser.

### Sync-back

Step 3 is what keeps profiles working over time. Codex refreshes its tokens
periodically and rewrites `auth.json`. If switching just overwrote that file,
the profile you switched *away* from would keep the refresh token it had when
you saved it — and stop working as soon as the server rotates it.

Profiles are matched by `account_id`, which survives token refreshes, rather
than by file contents, which do not.

### Orphans

An *orphan* is an active sign-in that matches no saved profile — you signed in
through the app without running `save`. Discarding it would throw away a real
session, so it's moved to an archive directory instead. Pass `--discard-orphan`
to delete it outright.

## Security

Saved profiles are working credentials — anyone who can read them can act as
you. The tool creates its directories `0700` and its files `0600`, and never
prints, logs, or passes tokens as arguments.

That said, they're files on disk, not a Keychain entry. If your threat model
includes other processes running as your user, this tool isn't for you.

See [SECURITY.md](SECURITY.md) to report a vulnerability.

## Platform support

| | Status |
| --- | --- |
| macOS | Full — quits and reopens the desktop app |
| Linux | Profile management works; no desktop app to drive, so close your CLI session first |
| Windows | Unsupported ([contributions welcome](CONTRIBUTING.md)) |

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `CODEX_HOME` | `~/.codex` | Codex's data directory (Codex's own variable) |
| `CODEX_ACCOUNT_HOME` | `${XDG_DATA_HOME:-~/.local/share}/codex-account` | Where profiles are stored |
| `CODEX_ACCOUNT_QUIT_TIMEOUT` | `20` | Seconds to wait for the app to exit |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `make check` before opening a PR.

## Disclaimer

Not affiliated with, endorsed by, or supported by OpenAI. "Codex" and "ChatGPT"
are trademarks of OpenAI. This tool reads and moves a local file; it relies on
that file's location and shape, which OpenAI can change at any time.

## License

[MIT](LICENSE)
