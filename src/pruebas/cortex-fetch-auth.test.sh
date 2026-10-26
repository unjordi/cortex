#!/usr/bin/env bash
# Matriz determinista de cortex-fetch (Linux): estados de auth + preservación de la última lectura real.
# Gemelo del test de macOS (macos/pruebas/); mismo contrato Jordi 2026-10-21. OS-aware en el path del
# state.json. Usa los seams test-only: no toca el filesystem de credenciales ni la red.
set -uo pipefail
FETCH="$(cd "$(dirname "$0")/../bin" && pwd)/cortex-fetch"
[[ -x "$FETCH" ]] || { echo "no encuentro cortex-fetch en $FETCH"; exit 2; }
# Path del state.json relativo al HOME sandbox, según plataforma del fetch.
if [[ "$(uname)" == "Darwin" ]]; then STATE_REL="Library/Caches/cortex/state.json"; else STATE_REL=".cache/cortex/state.json"; fi

now_ms=$(( $(date +%s) * 1000 ))
R_OK=$(( now_ms + 40*86400000 )); R_SOON=$(( now_ms + 1*3600000 )); R_DEAD=$(( now_ms - 1*3600000 ))
USAGE_FIX='{"five_hour":{"utilization":42,"resets_at":"2026-10-21T20:00:00Z"},"seven_day":{"utilization":10,"resets_at":"2026-10-28T00:00:00Z"},"limits":[]}'
creds(){ printf '{"claudeAiOauth":{"accessToken":"tok","refreshTokenExpiresAt":%s}}' "$1"; }
PASS=0; FAIL=0
chk(){ local lbl="$1" got="$2" exp="$3"; if [[ "$got" == "$exp" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ $lbl: got[$got] exp[$exp]"; fi; }
run(){ local sb="$1"; shift; env "$@" HOME="$sb" XDG_CACHE_HOME="$sb/.cache" CORTEX_FETCH_NO_CCUSAGE=1 PATH="$PATH" bash "$FETCH" >/dev/null 2>&1; cat "$sb/$STATE_REL"; }
seed_oauth(){ local sb="$1"; mkdir -p "$sb/$(dirname "$STATE_REL")"
  printf '%s\n' '{"updated_at":"2026-10-21T09:00:00Z","basis":"oauth","status":"warn","account_email":"jordi.serra@pind.mx","five_hour":{"percent":55,"resets_at":"2026-10-21T14:00:00Z"},"weekly":{"percent":30}}' > "$sb/$STATE_REL"; }

SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "1.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "1.stale" "$(jq -r .stale <<<"$J")" "false"
chk "1.auth" "$(jq -r .auth.state <<<"$J")" "ok"; chk "1.five%" "$(jq -r .five_hour.percent <<<"$J")" "42"; rm -rf "$SB"

SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_SOON)" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "2.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "2.auth" "$(jq -r .auth.state <<<"$J")" "expiring"; rm -rf "$SB"

SB=$(mktemp -d); seed_oauth "$SB"
J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP=401)
chk "3.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "3.stale" "$(jq -r .stale <<<"$J")" "true"
chk "3.auth" "$(jq -r .auth.state <<<"$J")" "expired"
chk "3.account-no-pisada" "$(jq -r .account_email <<<"$J")" "jordi.serra@pind.mx"
chk "3.five-preservado" "$(jq -r .five_hour.percent <<<"$J")" "55"
chk "3.updated-preservado" "$(jq -r .updated_at <<<"$J")" "2026-10-21T09:00:00Z"; rm -rf "$SB"

SB=$(mktemp -d); seed_oauth "$SB"
J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "4.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "4.stale" "$(jq -r .stale <<<"$J")" "true"
chk "4.auth" "$(jq -r .auth.state <<<"$J")" "no_credentials"
chk "4.account-preservada" "$(jq -r .account_email <<<"$J")" "jordi.serra@pind.mx"; rm -rf "$SB"

SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP="")
chk "5.basis" "$(jq -r .basis <<<"$J")" "null"; chk "5.status" "$(jq -r .status <<<"$J")" "error"
chk "5.five-null" "$(jq -r '.five_hour == null' <<<"$J")" "true"
chk "5.account-null" "$(jq -r '.account_email == null' <<<"$J")" "true"
chk "5.auth" "$(jq -r .auth.state <<<"$J")" "ok"; rm -rf "$SB"

SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP=401)
chk "6.basis" "$(jq -r .basis <<<"$J")" "null"; chk "6.status" "$(jq -r .status <<<"$J")" "error"
chk "6.auth" "$(jq -r .auth.state <<<"$J")" "expired"; rm -rf "$SB"

SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_DEAD)" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "7.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "7.auth" "$(jq -r .auth.state <<<"$J")" "expired"; rm -rf "$SB"

echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
