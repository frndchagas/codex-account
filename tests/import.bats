#!/usr/bin/env bats

load helpers/setup

setup() {
  setup_codex_account
  make_credential 'archived@example.com' 'acct-archived' 'rt-archived' \
    >"$BATS_TEST_TMPDIR/backup.json"
}

@test "import stores a credential file as a profile" {
  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" archived
  [ "$status" -eq 0 ]
  [ -f "$(profile_file archived)" ]
  [[ "$output" == *'archived@example.com'* ]]
}

@test "import leaves the source file alone" {
  "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" archived
  [ -f "$BATS_TEST_TMPDIR/backup.json" ]
}

@test "imported profiles are usable" {
  "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" archived
  run "$CODEX_ACCOUNT" use archived
  [ "$status" -eq 0 ]

  run "$CODEX_ACCOUNT" current
  [[ "$output" == *'archived (archived@example.com)'* ]]
}

@test "import writes the profile 0600" {
  chmod 644 "$BATS_TEST_TMPDIR/backup.json"
  "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" archived
  [ "$(file_mode "$(profile_file archived)")" = '600' ]
}

@test "import rejects a file that is not a credential" {
  printf 'just some text' >"$BATS_TEST_TMPDIR/junk"
  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/junk" junk
  [ "$status" -eq 1 ]
  [[ "$output" == *'does not look like a Codex credential'* ]]
  [ ! -e "$(profile_file junk)" ]
}

@test "import rejects a missing file" {
  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/nope.json" ghost
  [ "$status" -eq 1 ]
  [[ "$output" == *'no such file'* ]]
}

@test "import rejects a symlinked source" {
  ln -s "$BATS_TEST_TMPDIR/backup.json" "$BATS_TEST_TMPDIR/link.json"
  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/link.json" linked
  [ "$status" -eq 1 ]
  [[ "$output" == *'symlink'* ]]
}

@test "import validates the profile name" {
  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" '../escape'
  [ "$status" -eq 1 ]
  [[ "$output" == *'invalid profile name'* ]]
}

@test "import refuses to overwrite without --force" {
  "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" archived

  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json" archived
  [ "$status" -eq 1 ]
  [[ "$output" == *'already exists'* ]]

  run "$CODEX_ACCOUNT" --force import "$BATS_TEST_TMPDIR/backup.json" archived
  [ "$status" -eq 0 ]
}

@test "import --dry-run changes nothing" {
  run "$CODEX_ACCOUNT" --dry-run import "$BATS_TEST_TMPDIR/backup.json" archived
  [ "$status" -eq 0 ]
  [[ "$output" == *'Would import'* ]]
  [ ! -e "$(profile_file archived)" ]
}

@test "import requires both arguments" {
  run "$CODEX_ACCOUNT" import "$BATS_TEST_TMPDIR/backup.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *'usage:'* ]]
}
