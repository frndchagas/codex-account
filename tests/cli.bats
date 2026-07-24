#!/usr/bin/env bats

load helpers/setup

setup() {
  setup_codex_account
}

@test "no arguments prints help" {
  run "$CODEX_ACCOUNT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage:'* ]] || return 1
}

@test "--version prints name and version" {
  run "$CODEX_ACCOUNT" --version
  [ "$status" -eq 0 ]
  [[ "$output" == 'codex-account '* ]] || return 1
}

@test "unknown command exits 2" {
  run "$CODEX_ACCOUNT" nope
  [ "$status" -eq 2 ]
  [[ "$output" == *'unknown command'* ]] || return 1
}

@test "unknown option exits 2" {
  run "$CODEX_ACCOUNT" --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *'unknown option'* ]] || return 1
}

@test "save without a name is a usage error" {
  run "$CODEX_ACCOUNT" save
  [ "$status" -eq 1 ]
  [[ "$output" == *'usage:'* ]] || return 1
}

@test "save with extra arguments is a usage error" {
  run "$CODEX_ACCOUNT" save one two
  [ "$status" -eq 1 ]
  [[ "$output" == *'usage:'* ]] || return 1
}

@test "current exits non-zero when signed out" {
  run "$CODEX_ACCOUNT" current
  [ "$status" -eq 1 ]
  [[ "$output" == *'Not signed in'* ]] || return 1
}

@test "list explains itself when empty" {
  run "$CODEX_ACCOUNT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *'No profiles saved yet'* ]] || return 1
}

@test "--quiet suppresses informational output" {
  sign_in_as 'work@example.com' 'acct-work'
  run "$CODEX_ACCOUNT" --quiet save work
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "aliases resolve to the same commands" {
  sign_in_as 'work@example.com' 'acct-work'
  run "$CODEX_ACCOUNT" save work
  [ "$status" -eq 0 ]

  run "$CODEX_ACCOUNT" ls
  [ "$status" -eq 0 ]
  [[ "$output" == *'work'* ]] || return 1

  run "$CODEX_ACCOUNT" whoami
  [ "$status" -eq 0 ]
  [[ "$output" == *'work@example.com'* ]] || return 1
}
