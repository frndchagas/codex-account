#!/usr/bin/env bats

load helpers/setup

setup() {
  setup_codex_account
}

sessions_dir() {
  printf '%s/sessions/2026/08/08' "$CODEX_HOME"
}

# window_minutes 10080 is the weekly window, 300 the 5h one.
write_session() {
  local file="$1" ts="$2" limit_id="$3" weekly_used="$4" resets="$5" five_used="${6:-}"

  mkdir -p "$(sessions_dir)"
  {
    printf '{"timestamp":"%s","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"%s"' "$ts" "$limit_id"
    if [ -n "$five_used" ]; then
      printf ',"primary":{"used_percent":%s,"window_minutes":300,"resets_at":%s}' "$five_used" "$resets"
    else
      printf ',"primary":null'
    fi
    printf ',"secondary":{"used_percent":%s,"window_minutes":10080,"resets_at":%s},"plan_type":"pro"}}}\n' "$weekly_used" "$resets"
  } >>"$(sessions_dir)/$file"
}

write_filler() {
  local file="$1" bytes="$2"

  dd if=/dev/zero bs="$bytes" count=1 2>/dev/null |
    tr '\0' x >>"$(sessions_dir)/$file"
  printf '\n' >>"$(sessions_dir)/$file"
}

backdate_auth() {
  touch -t 202601010000 "$CODEX_HOME/auth.json"
}

future_epoch() {
  echo $(($(date '+%s') + 86400))
}

past_epoch() {
  echo $(($(date '+%s') - 86400))
}

@test "list stays column-free when no usage data exists" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" list
  [ "$status" -eq 0 ]
  [[ "$output" != *'% wk'* ]] || return 1
  [[ "$output" != *' - '* ]] || return 1
}

@test "list shows weekly percentage left for the active profile" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 38.5 "$(future_epoch)" 12.0
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *'61% wk'* ]] || return 1
}

@test "the worst weekly window across limit ids wins" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 10.0 "$(future_epoch)"
  write_session rollout-a.jsonl '2026-08-08T11:00:00.000Z' per_model 70.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" list
  [[ "$output" == *'30% wk'* ]] || return 1
}

@test "only the newest event per limit id counts" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 90.0 "$(future_epoch)"
  write_session rollout-a.jsonl '2026-08-08T11:00:00.000Z' premium 20.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" list
  [[ "$output" == *'80% wk'* ]] || return 1
}

@test "usage scan reads only a bounded tail of each session" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 90.0 "$(future_epoch)"
  write_filler rollout-a.jsonl 2048

  CODEX_ACCOUNT_USAGE_SCAN_TAIL_BYTES=1024 run "$CODEX_ACCOUNT" list
  [[ "$output" != *'% wk'* ]] || return 1

  write_session rollout-a.jsonl '2026-08-08T11:00:00.000Z' premium 20.0 "$(future_epoch)"
  CODEX_ACCOUNT_USAGE_SCAN_TAIL_BYTES=1024 run "$CODEX_ACCOUNT" list
  [[ "$output" == *'80% wk'* ]] || return 1
}

@test "usage scan inspects only the configured number of newest sessions" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 90.0 "$(future_epoch)"
  write_filler rollout-b.jsonl 128
  write_filler rollout-c.jsonl 128

  CODEX_ACCOUNT_USAGE_SCAN_MAX_FILES=2 run "$CODEX_ACCOUNT" list
  [[ "$output" != *'% wk'* ]] || return 1

  write_session rollout-c.jsonl '2026-08-08T11:00:00.000Z' premium 20.0 "$(future_epoch)"
  CODEX_ACCOUNT_USAGE_SCAN_MAX_FILES=2 run "$CODEX_ACCOUNT" list
  [[ "$output" == *'80% wk'* ]] || return 1
}

@test "usage scan bounds must be positive whole numbers" {
  CODEX_ACCOUNT_USAGE_SCAN_MAX_FILES=0 run "$CODEX_ACCOUNT" list
  [ "$status" -eq 1 ]
  [[ "$output" == *'must be greater than zero'* ]] || return 1

  CODEX_ACCOUNT_USAGE_SCAN_TAIL_BYTES=invalid run "$CODEX_ACCOUNT" list
  [ "$status" -eq 1 ]
  [[ "$output" == *'must be a positive whole number'* ]] || return 1
}

@test "sessions older than the credential are not attributed to it" {
  sign_in_as 'work@example.com' 'acct-work'
  write_session rollout-old.jsonl '2026-08-08T10:00:00.000Z' premium 90.0 "$(future_epoch)"
  sleep 1
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  run "$CODEX_ACCOUNT" list
  [[ "$output" != *'% wk'* ]] || return 1
}

@test "use snapshots the departing profile's usage" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 38.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save work

  sign_in_as 'personal@example.com' 'acct-personal'
  sleep 1
  write_session rollout-b.jsonl '2026-08-08T12:00:00.000Z' premium 80.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save personal
  "$CODEX_ACCOUNT" use work

  [ -f "$CODEX_ACCOUNT_HOME/usage/personal.json" ]

  run "$CODEX_ACCOUNT" list
  [[ "$output" == *'62% wk'* ]] || return 1
  [[ "$output" == *'20% wk'* ]] || return 1
}

@test "a past reset upgrades a snapshot to 100%" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 95.0 "$(past_epoch)"
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" list
  [[ "$output" == *'100% wk'* ]] || return 1

  run "$CODEX_ACCOUNT" limits
  [[ "$output" == *'reset happened since last use'* ]] || return 1
}

@test "limits reports both windows with reset times" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 38.0 "$(future_epoch)" 15.0
  "$CODEX_ACCOUNT" save work

  run "$CODEX_ACCOUNT" limits
  [ "$status" -eq 0 ]
  [[ "$output" == *'weekly  62% left'* ]] || return 1
  [[ "$output" == *'5h      85% left'* ]] || return 1
  [[ "$output" == *'resets'* ]] || return 1
}

@test "limits points out profiles with no data" {
  sign_in_as 'work@example.com' 'acct-work'
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal

  run "$CODEX_ACCOUNT" limits
  [ "$status" -eq 0 ]
  # work is now inactive and never had data; personal is active without data
  [[ "$output" == *'no data yet'* ]] || return 1
  [[ "$output" == *'use Codex on this account'* ]] || return 1
}

@test "usage numbers do not depend on jq" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 38.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save work

  CODEX_ACCOUNT_FAKE_NO_JQ=1 run "$CODEX_ACCOUNT" list
  [[ "$output" == *'62% wk'* ]] || return 1
}

@test "remove deletes the profile's usage snapshot" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 38.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save work
  sign_in_as 'personal@example.com' 'acct-personal'
  "$CODEX_ACCOUNT" save personal
  "$CODEX_ACCOUNT" remove work

  [ ! -e "$CODEX_ACCOUNT_HOME/usage/work.json" ]
}

@test "dry-run use does not write a snapshot" {
  sign_in_as 'work@example.com' 'acct-work'
  backdate_auth
  write_session rollout-a.jsonl '2026-08-08T10:00:00.000Z' premium 38.0 "$(future_epoch)"
  "$CODEX_ACCOUNT" save work
  mkdir -p "$CODEX_ACCOUNT_HOME/profiles"
  make_credential 'personal@example.com' 'acct-personal' >"$CODEX_ACCOUNT_HOME/profiles/personal.json"

  rm -f "$CODEX_ACCOUNT_HOME/usage/work.json"
  run "$CODEX_ACCOUNT" --dry-run use personal
  [ "$status" -eq 0 ]
  [ ! -e "$CODEX_ACCOUNT_HOME/usage/work.json" ]
}
