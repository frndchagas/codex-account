# Security Policy

## Reporting a vulnerability

Please report security issues privately through
[GitHub Security Advisories](https://github.com/frndchagas/codex-account/security/advisories/new)
rather than opening a public issue.

Expect an initial response within 7 days. If a fix is warranted, we'll agree on
a disclosure timeline with you before publishing.

## Scope

This tool moves a credential file around on your machine. The issues that
matter most:

- Anything that leaks token contents (into logs, argv, temp files, or error
  output).
- Anything that lets a path outside the profiles directory be written or read
  — profile names are validated and symlinks rejected for this reason.
- Anything that causes a credential to be moved while Codex is running, since
  the app can write stale tokens back over it.
- Anything that leaves credentials with permissions looser than `0600`.

Out of scope: an attacker who already runs code as your user. Profiles are
files on disk protected by filesystem permissions, not by encryption.

## What this tool does not do

It never contacts OpenAI, never calls `codex logout`, and never touches browser
state. If you observe otherwise, that is a security bug — please report it.
