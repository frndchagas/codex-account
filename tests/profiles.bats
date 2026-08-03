#!/usr/bin/env bats

load helpers/setup

setup() {
  setup_codex_account
}

@test "save stores the active credential under a name" {
  sign_in_as 'work@example.com' 'acct-work'
  run "$CODEX_ACCOUNT" save work
  [ "$status" -eq 0 ]
  [ -f "$(profile_file work)" ]
  [[ "$output" == *'work@example.com'* ]] || return 1
}

@test "save refuses when nobody is signed in" {
  run "$CODEX_ACCOUNT" save work
  [ "$status" -eq 1 ]
  [[ "$output" == *'no active sign-in'* ]] || return 1
}

@test "save refuses to overwrite without --force" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  sign_in_as 'other@example.com' 'acct-other'
  run "$CODEX_ACCOUNT" save work
  [ "$status" -eq 1 ]
  [[ "$output" == *'already exists'* ]] || return 1

  run "$CODEX_ACCOUNT" --force save work
  [ "$status" -eq 0 ]
}

@test "list marks the active profile" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  run "$CODEX_ACCOUNT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *'* personal'* ]] || return 1
  [[ "$output" != *'* work'* ]] || return 1
}

@test "use switches the active credential" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 0 ]

  run "$CODEX_ACCOUNT" current
  [[ "$output" == *'work (work@example.com)'* ]] || return 1
}

@test "use is a no-op when the profile is already active" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 0 ]
  [[ "$output" == *'Already signed in'* ]] || return 1
}

@test "use rejects an unknown profile" {
  run "$CODEX_ACCOUNT" use ghost
  [ "$status" -eq 1 ]
  [[ "$output" == *'no such profile'* ]] || return 1
}

@test "use writes refreshed tokens back to the origin profile" {
  sign_in_as 'work@example.com' 'acct-work' 'rt-original'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  "$CODEX_ACCOUNT" use work
  sign_in_as 'work@example.com' 'acct-work' 'rt-rotated'
  "$CODEX_ACCOUNT" use personal

  run grep -c 'rt-rotated' "$(profile_file work)"
  [ "$status" -eq 0 ]
}

@test "use does not launch Codex when it was not running" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  export CODEX_ACCOUNT_FAKE_PLATFORM=macos
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 0 ]
  [[ "$output" != *'Codex reopened.'* ]] || return 1
}

@test "use reopens Codex when the switch is what closed it" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  export CODEX_ACCOUNT_FAKE_PLATFORM=macos CODEX_ACCOUNT_FAKE_RUNNING=1
  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 0 ]
  [[ "$output" == *'Quitting Codex...'* ]] || return 1
  [[ "$output" == *'Codex reopened.'* ]] || return 1
}

@test "forget signs out locally and keeps the profile" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" forget
  [ "$status" -eq 0 ]
  [ ! -e "$CODEX_HOME/auth.json" ]
  [ -f "$(profile_file work)" ]
}

@test "forget is idempotent" {
  run "$CODEX_ACCOUNT" forget
  [ "$status" -eq 0 ]
  [[ "$output" == *'Already signed out'* ]] || return 1
}

@test "forget does not launch Codex when it was not running" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  export CODEX_ACCOUNT_FAKE_PLATFORM=macos
  run "$CODEX_ACCOUNT" forget
  [ "$status" -eq 0 ]
  [[ "$output" != *'Codex reopened.'* ]] || return 1
}

@test "remove deletes an inactive profile" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  "$CODEX_ACCOUNT" forget

  run "$CODEX_ACCOUNT" remove work
  [ "$status" -eq 0 ]
  [ ! -e "$(profile_file work)" ]
}

@test "remove refuses the active profile without --force" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" remove work
  [ "$status" -eq 1 ]
  [[ "$output" == *'currently active'* ]] || return 1

  run "$CODEX_ACCOUNT" --force remove work
  [ "$status" -eq 0 ]
}

@test "an unsaved sign-in is archived rather than dropped" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  "$CODEX_ACCOUNT" forget
  sign_in_as 'orphan@example.com' 'acct-orphan' 'rt-orphan'

  run "$CODEX_ACCOUNT" use work
  [ "$status" -eq 0 ]

  run grep -rl 'rt-orphan' "$CODEX_ACCOUNT_HOME/archive"
  [ "$status" -eq 0 ]
}

@test "--discard-orphan drops the unsaved sign-in" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  "$CODEX_ACCOUNT" forget
  sign_in_as 'orphan@example.com' 'acct-orphan' 'rt-orphan'

  run "$CODEX_ACCOUNT" --discard-orphan use work
  [ "$status" -eq 0 ]
  [ ! -d "$CODEX_ACCOUNT_HOME/archive" ]
}

@test "profiles are matched by account id, not file contents" {
  sign_in_as 'work@example.com' 'acct-work' 'rt-one'
  "$CODEX_ACCOUNT" save work

  sign_in_as 'work@example.com' 'acct-work' 'rt-two'
  run "$CODEX_ACCOUNT" current
  [[ "$output" == *'work (work@example.com)'* ]] || return 1
}

@test "a credential without a readable e-mail still works" {
  printf '{"tokens":{"account_id":"acct-weird","refresh_token":"rt"}}' >"$CODEX_HOME/auth.json"

  run "$CODEX_ACCOUNT" save weird
  [ "$status" -eq 0 ]
  [[ "$output" == *'unknown account'* ]] || return 1
}

@test "--dry-run changes nothing" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  run "$CODEX_ACCOUNT" --dry-run use work
  [ "$status" -eq 0 ]
  [[ "$output" == *'Would switch'* ]] || return 1

  run "$CODEX_ACCOUNT" current
  [[ "$output" == *'personal'* ]] || return 1
}
