## What and why

<!-- What changes, and what problem it solves. -->

## Checklist

- [ ] `make check` passes (lint, formatting, tests)
- [ ] Tests cover the behaviour change
- [ ] Still works under bash 3.2 — `/bin/bash tests` on macOS (no associative
      arrays, no empty-array expansion under `set -u`)
- [ ] No new code path can quit or launch the real app under
      `CODEX_ACCOUNT_TEST_MODE`
- [ ] No token value is printed, logged, or passed as an argument
- [ ] `README.md` updated if the interface changed
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`
