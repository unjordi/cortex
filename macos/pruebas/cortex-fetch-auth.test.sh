#!/usr/bin/env bash
# Matriz determinista de cortex-fetch (macOS): estados de auth + preservación de la última lectura real.
# Contrato Jordi 2026-10-21: el estimado por costo NUNCA pisa una lectura oauth real; en fallo de OAuth
# se muestra la última real con su cuenta y antigüedad, o "no hay dato" si no hay previa (no inventa).
# Usa los seams test-only (CORTEX_FETCH_CREDS_JSON / CORTEX_FETCH_HTTP / CORTEX_FETCH_USAGE_FIXTURE /
# CORTEX_FETCH_NO_CCUSAGE): no toca el llavero ni la red. Solo macOS (cortex-fetch usa BSD `date`).
set -uo pipefail
FETCH="$(cd "$(dirname "$0")/../bin" && pwd)/cortex-fetch"
[[ -x "$FETCH" ]] || { echo "no encuentro cortex-fetch en $FETCH"; exit 2; }

now_ms=$(( $(date +%s) * 1000 ))
R_OK=$(( now_ms + 40*86400000 ))     # refresh token sano (40d)
R_SOON=$(( now_ms + 1*3600000 ))     # refresh token dentro de ventana (1h)
R_DEAD=$(( now_ms - 1*3600000 ))     # refresh token vencido
USAGE_FIX='{"five_hour":{"utilization":42,"resets_at":"2026-10-21T20:00:00Z"},"seven_day":{"utilization":10,"resets_at":"2026-10-28T00:00:00Z"},"limits":[]}'
creds(){ printf '{"claudeAiOauth":{"accessToken":"tok","refreshTokenExpiresAt":%s}}' "$1"; }
PASS=0; FAIL=0
chk(){ local lbl="$1" got="$2" exp="$3"; if [[ "$got" == "$exp" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ $lbl: got[$got] exp[$exp]"; fi; }
run(){ local sb="$1"; shift; env "$@" HOME="$sb" CORTEX_FETCH_NO_CCUSAGE=1 PATH="$PATH" bash "$FETCH" >/dev/null 2>&1; cat "$sb/Library/Caches/cortex/state.json"; }
seed_oauth(){ local sb="$1"; mkdir -p "$sb/Library/Caches/cortex"
  cat > "$sb/Library/Caches/cortex/state.json" <<EOF
{"updated_at":"2026-10-21T09:00:00Z","basis":"oauth","status":"warn","account_email":"jordi.serra@pind.mx","five_hour":{"percent":55,"resets_at":"2026-10-21T14:00:00Z"},"weekly":{"percent":30}}
EOF
}

# Caso 1: oauth-fresco + auth ok
SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "1.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "1.stale" "$(jq -r .stale <<<"$J")" "false"
chk "1.auth" "$(jq -r .auth.state <<<"$J")" "ok"; chk "1.five%" "$(jq -r .five_hour.percent <<<"$J")" "42"; rm -rf "$SB"

# Caso 2: oauth-fresco + expiring
SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_SOON)" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "2.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "2.auth" "$(jq -r .auth.state <<<"$J")" "expiring"; rm -rf "$SB"

# Caso 3: 401 + lectura previa → PRESERVA (no pisa cuenta/números/updated_at)
SB=$(mktemp -d); seed_oauth "$SB"
J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP=401)
chk "3.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "3.stale" "$(jq -r .stale <<<"$J")" "true"
chk "3.auth" "$(jq -r .auth.state <<<"$J")" "expired"
chk "3.account-no-pisada" "$(jq -r .account_email <<<"$J")" "jordi.serra@pind.mx"
chk "3.five-preservado" "$(jq -r .five_hour.percent <<<"$J")" "55"
chk "3.updated-preservado" "$(jq -r .updated_at <<<"$J")" "2026-10-21T09:00:00Z"; rm -rf "$SB"

# Caso 4: sin credenciales + lectura previa → PRESERVA con auth=no_credentials
SB=$(mktemp -d); seed_oauth "$SB"
J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "4.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "4.stale" "$(jq -r .stale <<<"$J")" "true"
chk "4.auth" "$(jq -r .auth.state <<<"$J")" "no_credentials"
chk "4.account-preservada" "$(jq -r .account_email <<<"$J")" "jordi.serra@pind.mx"; rm -rf "$SB"

# Caso 5: red caída (HTTP vacío) SIN previa → no-data honesto (no inventa estimado)
SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP="")
chk "5.basis" "$(jq -r .basis <<<"$J")" "null"; chk "5.status" "$(jq -r .status <<<"$J")" "error"
chk "5.five-null" "$(jq -r '.five_hour == null' <<<"$J")" "true"
chk "5.account-null" "$(jq -r '.account_email == null' <<<"$J")" "true"
chk "5.auth" "$(jq -r .auth.state <<<"$J")" "ok"; rm -rf "$SB"

# Caso 6: 401 SIN previa → no-data con auth=expired
SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_OK)" CORTEX_FETCH_HTTP=401)
chk "6.basis" "$(jq -r .basis <<<"$J")" "null"; chk "6.status" "$(jq -r .status <<<"$J")" "error"
chk "6.auth" "$(jq -r .auth.state <<<"$J")" "expired"; rm -rf "$SB"

# Caso 7: refresh token vencido (200 igual) → expired aunque el fetch salga OK
SB=$(mktemp -d); J=$(run "$SB" CORTEX_FETCH_CREDS_JSON="$(creds $R_DEAD)" CORTEX_FETCH_HTTP=200 CORTEX_FETCH_USAGE_FIXTURE="$USAGE_FIX")
chk "7.basis" "$(jq -r .basis <<<"$J")" "oauth"; chk "7.auth" "$(jq -r .auth.state <<<"$J")" "expired"; rm -rf "$SB"

echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
