# Contributing

Thanks for taking a look. This is a small, deliberately boring tool that
handles credentials, so changes are held to a higher bar than the line count
might suggest.

## Development setup

```sh
brew install shellcheck shfmt bats-core     # macOS
sudo apt install shellcheck bats            # Debian/Ubuntu; shfmt via its own release

make check                                  # lint + format check + tests
```

## Ground rules

**Never test against a real Codex install.** Tests set
`CODEX_ACCOUNT_TEST_MODE=1`, which stubs process detection and hard-blocks the
code paths that quit or launch the app. If you add a code path that drives the
application, route it through `ask_app_to_quit` / `open_app` so that guard
still holds.

**Target bash 3.2.** macOS ships bash 3.2 and that's what most users will run
this under. No associative arrays, no `readarray`, and remember that expanding
an empty array under `set -u` is an error there.

**Never print tokens.** Only `account_id` and `email` are read out of a
credential file, and only `email` is ever displayed.

**Fail closed.** If the tool cannot establish that Codex is stopped, it must
abort without touching the credential. When in doubt, do nothing and say why.

**Comment sparingly.** Explain decisions the code can't — a guard's purpose, a
platform quirk. Don't restate what the next line already says.

## Pull requests

- One logical change per PR.
- Add tests for behaviour changes; `tests/` covers the CLI end to end.
- Update `README.md` if you change the interface, and `CHANGELOG.md` under
  `## [Unreleased]`.
- Keep commit subjects imperative and under 72 characters.

## Adding platform support

Windows is the obvious gap. The credential handling is portable; what isn't is
process detection and driving the desktop app. A port should keep the same
guarantees — refuse to act while the app runs, atomic installs, `0600` files —
rather than approximate them.
