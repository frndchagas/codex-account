# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Every process running the codex binary — the TUI, `codex exec`, an IDE
  session — now blocks a switch, not just an `app-server`. Each of them holds
  `auth.json` in memory and writes it back on its own schedule, so proceeding
  would corrupt the credential the same way; close the session and rerun.

### Fixed

- The quit wait now sees the desktop app's real backend. The app launches it
  with flags between the binary and the subcommand (`codex -c
  features.code_mode_host=true app-server`), which the old pattern did not
  match, so the switch could proceed while that process was still shutting
  down — and its exit write-back then clobbered the freshly installed
  credential, leaving the reopened app unable to start new threads until it
  was restarted by hand. The same blind spot let an orphaned backend slip
  past the "CLI session is still running" guard.
- Codex is only reopened after `use` or `forget` if the switch is what closed
  it. It used to be launched unconditionally, including when it was not
  running to begin with.

## [0.2.0] - 2026-07-24

### Added

- `import <file> <name>` turns an existing credential file into a profile,
  with validation and correct permissions, so credentials saved by hand no
  longer have to be copied manually.
- `list` reports how many archived sign-ins are still on disk. Archiving is the
  safe default for an unsaved credential, but the notice only appeared once,
  and those files keep working indefinitely.

### Security

- Credential fields are read from one named object rather than searched for
  anywhere in the document. The old search let the two readers disagree — `jq`
  returned the first match in traversal order, the greedy `sed` fallback the
  last — so a repeated `account_id` could identify a different account
  depending only on whether `jq` happened to be installed, and sync-back would
  then write one account's tokens into another account's profile.
- Profile names are no longer validated with `grep`, which is line-oriented and
  succeeds on any matching line: a name containing a newline passed on the
  strength of its first line alone, so the rest could hold arbitrary bytes.
- E-mails read from the (deliberately unverified) `id_token`, and profile names
  read back off disk, are stripped of control bytes before being printed. A
  crafted credential could otherwise emit terminal escapes that rewrite the
  output and hide which account is active.
- A non-numeric `CODEX_ACCOUNT_QUIT_TIMEOUT` made the wait loop's test error
  out, which read as "not expired yet" and never timed out.
- The profiles directory mode is verified after `chmod` rather than assumed,
  and a directory that cannot be brought to 0700 is now reported.
- Dying between `mktemp` and `mv` no longer strands a complete credential under
  the temporary name.

### Fixed

- A declined quit dialog (AppleScript error -128) is now reported as such
  instead of as a failure to reach the app, since the two need different
  actions from the user.
- App-server detection no longer matches the caller's own process tree. Any
  shell whose command line merely mentioned `codex` and `app-server` used to
  look like a running Codex and block the switch.

## [0.1.0] - 2026-07-24

Initial release.

### Added

- `save`, `use`, `list`, `current`, `remove` and `forget` commands for managing
  multiple local Codex sign-ins.
- Sync-back: the live credential is written to its own profile before switching
  away, so refreshed tokens survive a switch.
- Profiles identified by `account_id`, which is stable across token refreshes.
- Orphan archiving for active sign-ins that were never saved as a profile,
  with `--discard-orphan` to opt out.
- Guards against acting while Codex is running, being launched from a terminal
  inside Codex, and symlinked credential paths.
- `--dry-run` for every mutating command.
- macOS and Linux support; bash 3.2 compatible.

[Unreleased]: https://github.com/frndchagas/codex-account/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/frndchagas/codex-account/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/frndchagas/codex-account/releases/tag/v0.1.0
