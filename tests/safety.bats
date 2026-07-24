#!/usr/bin/env bats

load helpers/setup

setup() {
  setup_codex_account
}

@test "profile names cannot escape the profiles directory" {
  sign_in_as 'work@example.com' 'acct-work'

  for name in '../evil' '/etc/passwd' 'a/b' '.hidden' '-flag' ''; do
    run "$CODEX_ACCOUNT" save "$name"
    [ "$status" -ne 0 ]
  done

  [ ! -e "$BATS_TEST_TMPDIR/evil.json" ]
}

@test "a symlinked credential is refused" {
  printf 'not a credential' >"$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$CODEX_HOME/auth.json"

  run "$CODEX_ACCOUNT" save work
  [ "$status" -eq 1 ]
  [[ "$output" == *'symlink'* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/elsewhere")" = 'not a credential' ]
}

@test "a running Codex that will not quit blocks the switch" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  export CODEX_ACCOUNT_FAKE_RUNNING=1 CODEX_ACCOUNT_FAKE_QUIT_FAILS=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]
  [[ "$output" == *'no credential was changed'* ]]

  run "$CODEX_ACCOUNT" current
  [[ "$output" == *'personal'* ]]
}

@test "being launched from inside Codex is refused" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'

  export CODEX_ACCOUNT_FAKE_RUNNING=1 CODEX_ACCOUNT_FAKE_INSIDE=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]
  [[ "$output" == *'inside Codex'* ]]
}

@test "an open CLI session blocks the switch" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'

  export CODEX_ACCOUNT_FAKE_CLI_RUNNING=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]
  [[ "$output" == *'CLI session is still running'* ]]
}

@test "a declined quit dialog is reported as such" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'

  export CODEX_ACCOUNT_FAKE_PLATFORM=macos
  export CODEX_ACCOUNT_FAKE_RUNNING=1 CODEX_ACCOUNT_FAKE_QUIT=canceled
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]
  [[ "$output" == *'confirmation dialog'* ]]
  [[ "$output" == *'no credential was changed'* ]]
}

@test "an unreachable app is reported differently from a declined dialog" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'

  export CODEX_ACCOUNT_FAKE_PLATFORM=macos
  export CODEX_ACCOUNT_FAKE_RUNNING=1 CODEX_ACCOUNT_FAKE_QUIT=fails
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]
  [[ "$output" == *'could not ask Codex to quit'* ]]
  [[ "$output" != *'confirmation dialog'* ]]
}

@test "the caller's own process tree is not mistaken for an app-server" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  unset CODEX_ACCOUNT_TEST_MODE
  export CODEX_ACCOUNT_QUIT_TIMEOUT=2

  run bash -c ': codex app-server; "$1" list' _ "$CODEX_ACCOUNT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'work'* ]]
}

@test "profiles are written 0600 inside a 0700 directory" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  [ "$(file_mode "$(profile_file work)")" = '600' ]
  [ "$(file_mode "$CODEX_ACCOUNT_HOME/profiles")" = '700' ]
}

@test "tokens never reach stdout or stderr" {
  sign_in_as 'work@example.com' 'acct-work' 'rt-super-secret'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal' 'rt-also-secret'
  "$CODEX_ACCOUNT" save personal

  run "$CODEX_ACCOUNT" use work
  [[ "$output" != *'rt-super-secret'* ]]
  [[ "$output" != *'rt-also-secret'* ]]
  [[ "$output" != *'hdr.'* ]]

  run "$CODEX_ACCOUNT" list
  [[ "$output" != *'rt-'* ]]
}

@test "a failed switch leaves the previous credential intact" {
  sign_in_as 'work@example.com' 'acct-work' 'rt-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal' 'rt-personal'

  export CODEX_ACCOUNT_FAKE_RUNNING=1 CODEX_ACCOUNT_FAKE_QUIT_FAILS=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]

  run grep -c 'rt-personal' "$CODEX_HOME/auth.json"
  [ "$status" -eq 0 ]
}

@test "on Linux a running Codex is reported as a CLI session" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'

  export CODEX_ACCOUNT_FAKE_PLATFORM=linux CODEX_ACCOUNT_FAKE_RUNNING=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]
  [[ "$output" == *'CLI session is still running'* ]]
  [[ "$output" != *'Quitting Codex'* ]]
}

@test "an unsupported platform is refused" {
  export CODEX_ACCOUNT_FAKE_PLATFORM=unsupported
  run "$CODEX_ACCOUNT" list
  [ "$status" -eq 1 ]
  [[ "$output" == *'unsupported platform'* ]]
}

@test "a profile name cannot smuggle a second line past validation" {
  sign_in_as 'work@example.com' 'acct-work'

  run "$CODEX_ACCOUNT" save "$(printf 'ok\nEVIL')"
  [ "$status" -ne 0 ]

  run "$CODEX_ACCOUNT" save "$(printf 'ok\n../../escaped')"
  [ "$status" -ne 0 ]

  [ -z "$(find "$CODEX_ACCOUNT_HOME" -name '*EVIL*' 2>/dev/null)" ]
  [ ! -e "$BATS_TEST_TMPDIR/escaped.json" ]
}

@test "a profile name cannot carry terminal escapes" {
  sign_in_as 'work@example.com' 'acct-work'

  run "$CODEX_ACCOUNT" save "$(printf 'ok\n\033[31mfake')"
  [ "$status" -ne 0 ]
  [[ "$output" != *$'\033'* ]]
}

@test "an over-long profile name is refused" {
  sign_in_as 'work@example.com' 'acct-work'

  run "$CODEX_ACCOUNT" save "$(printf 'a%.0s' $(seq 65))"
  [ "$status" -ne 0 ]
  [[ "$output" == *'64 characters'* ]]
}

@test "terminal escapes in a credential email never reach the output" {
  local claims
  claims="$(printf '{"email":"\033[2K\rspoofed@example.com","email_verified":true}' | base64url)"
  printf '{"auth_mode":"chatgpt","tokens":{"id_token":"hdr.%s.sig","refresh_token":"rt","account_id":"acct-evil"}}' \
    "$claims" >"$CODEX_HOME/auth.json"
  chmod 600 "$CODEX_HOME/auth.json"

  "$CODEX_ACCOUNT" save evil

  run "$CODEX_ACCOUNT" list
  [[ "$output" == *'spoofed@example.com'* ]]
  [[ "$output" != *$'\033'* ]]
  [[ "$output" != *$'\r'* ]]

  run "$CODEX_ACCOUNT" current
  [[ "$output" != *$'\033'* ]]
}

@test "a non-numeric quit timeout is refused instead of looping forever" {
  sign_in_as 'work@example.com' 'acct-work'

  export CODEX_ACCOUNT_QUIT_TIMEOUT=abc
  run "$CODEX_ACCOUNT" list
  [ "$status" -eq 1 ]
  [[ "$output" == *'whole number of seconds'* ]]
}

@test "a symlinked profiles directory is not mistaken for a loose one" {
  sign_in_as 'work@example.com' 'acct-work'

  mkdir -p "$CODEX_ACCOUNT_HOME" "$BATS_TEST_TMPDIR/elsewhere"
  chmod 700 "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$CODEX_ACCOUNT_HOME/profiles"

  run "$CODEX_ACCOUNT" save work
  [ "$status" -eq 0 ]
  [[ "$output" != *'not 700'* ]]
  [ -f "$BATS_TEST_TMPDIR/elsewhere/work.json" ]
}

@test "a failed install leaves no temporary credential behind" {
  sign_in_as 'work@example.com' 'acct-work' 'rt-leaked'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'

  export CODEX_ACCOUNT_FAKE_RUNNING=1 CODEX_ACCOUNT_FAKE_QUIT_FAILS=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 1 ]

  [ -z "$(find "$CODEX_ACCOUNT_HOME" "$CODEX_HOME" -name '*.json.??????' 2>/dev/null)" ]
}
