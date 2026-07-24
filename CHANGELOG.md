# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/frndchagas/codex-account/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/frndchagas/codex-account/releases/tag/v0.1.0
