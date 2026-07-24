#!/usr/bin/env bash

setup_codex_account() {
  export CODEX_HOME="$BATS_TEST_TMPDIR/codex"
  export CODEX_ACCOUNT_HOME="$BATS_TEST_TMPDIR/data"
  export CODEX_ACCOUNT_TEST_MODE=1
  export CODEX_ACCOUNT_QUIT_TIMEOUT=2

  unset CODEX_ACCOUNT_FAKE_RUNNING
  unset CODEX_ACCOUNT_FAKE_CLI_RUNNING
  unset CODEX_ACCOUNT_FAKE_INSIDE
  unset CODEX_ACCOUNT_FAKE_QUIT_FAILS

  mkdir -p "$CODEX_HOME"
  CODEX_ACCOUNT="$BATS_TEST_DIRNAME/../bin/codex-account"
  export CODEX_ACCOUNT
}

base64url() {
  base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

# A credential file shaped like the real one: an unsigned JWT carrying the
# e-mail, plus the account_id used to tell profiles apart.
make_credential() {
  local email="$1" account_id="$2" refresh="${3:-rt-default}" claims

  claims="$(printf '{"email":"%s","email_verified":true}' "$email" | base64url)"

  printf '{"auth_mode":"chatgpt","OPENAI_API_KEY":null,"tokens":{"id_token":"hdr.%s.sig","access_token":"at-%s","refresh_token":"%s","account_id":"%s"},"last_refresh":"2026-07-24T09:31:00.000Z"}' \
    "$claims" "$account_id" "$refresh" "$account_id"
}

sign_in_as() {
  make_credential "$@" >"$CODEX_HOME/auth.json"
  chmod 600 "$CODEX_HOME/auth.json"
}

profile_file() {
  printf '%s/profiles/%s.json' "$CODEX_ACCOUNT_HOME" "$1"
}

file_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}
