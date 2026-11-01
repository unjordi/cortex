#!/usr/bin/env bash
# cortex-fetch (macOS): agregados de transcripts INCREMENTALES por archivo.
# Verifica el PROPÓSITO (no la plomería): sobre un fixture de contenido conocido,
# que MESSAGES/PEAK/DAY_MSG y los tokens por proyecto sean correctos (dedup de
# msg_id, PEAK=todas las líneas con ts vs DAY_MSG=solo assistant|user), y que el
# caché por archivo re-escanee SOLO lo nuevo/cambiado (no los 3.1 GB completos).
# Falla contra el código viejo: no existía el subcomando ni el caché incremental.
# Usa el seam CORTEX_FETCH_CACHE_DIR (caché aislado) + el subcomando --transcript-stats-json
# con offset FIJO 0 (determinista). Solo macOS (cortex-fetch usa BSD `date`/`stat`).
set -uo pipefail
FETCH="$(cd "$(dirname "$0")/../bin" && pwd)/cortex-fetch"
[[ -x "$FETCH" ]] || { echo "no encuentro cortex-fetch en $FETCH"; exit 2; }

PASS=0; FAIL=0
chk(){ local lbl="$1" got="$2" exp="$3"; if [[ "$got" == "$exp" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ $lbl: got[$got] exp[$exp]"; fi; }

SB="$(mktemp -d)"; CACHE="$SB/cache"; PROJ="$SB/projects"
mkdir -p "$CACHE" "$PROJ/fa" "$PROJ/fb"
trap 'rm -rf "$SB"' EXIT

# Fixture determinista (offset 0 => día/hora UTC):
# fa: user 10-01T09 + assistant 10-01T09 (msg_A1, in100 out50) + DUPLICADO de msg_A1
#     (bloque de contenido repetido => cuenta como mensaje pero NO re-suma tokens).
cat > "$PROJ/fa/s1.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-01T09:00:00Z","cwd":"/Users/u/code/projX"}
{"type":"assistant","timestamp":"2026-10-01T09:30:00Z","message":{"id":"msg_A1","usage":{"input_tokens":100,"output_tokens":50}},"cwd":"/Users/u/code/projX"}
{"type":"assistant","timestamp":"2026-10-01T09:31:00Z","message":{"id":"msg_A1","usage":{"input_tokens":100,"output_tokens":50}},"cwd":"/Users/u/code/projX"}
EOF
# fb: assistant 10-02T15 (msg_B1, in7 out3) en otro proyecto.
cat > "$PROJ/fb/s2.jsonl" <<'EOF'
{"type":"assistant","timestamp":"2026-10-02T15:00:00Z","message":{"id":"msg_B1","usage":{"input_tokens":7,"output_tokens":3}},"cwd":"/Users/u/code/projY"}
EOF

run(){ env CORTEX_FETCH_CACHE_DIR="$CACHE" bash "$FETCH" --transcript-stats-json "$PROJ" 0 2>/dev/null; }
scanned(){ cat "$CACHE/.transcripts.lastscan" 2>/dev/null; }

# ── Run 1 (caché FRÍO): debe escanear los 2 archivos (no 0 — el bug empty-first-file) ──
J1="$(run)"
chk "1.scanned"  "$(scanned)" "2"
chk "1.sessions" "$(jq -r .sessions <<<"$J1")" "2"
chk "1.messages" "$(jq -r .messages <<<"$J1")" "4"    # L1 L2 L3 L4 (type assistant|user)
chk "1.peak"     "$(jq -r .peak <<<"$J1")" "9"        # hora 09 (3 líneas con ts) > hora 15 (1)
chk "1.dm.10-01" "$(jq -r '.day_msg["2026-10-01"]' <<<"$J1")" "3"
chk "1.dm.10-02" "$(jq -r '.day_msg["2026-10-02"]' <<<"$J1")" "1"
# tokens por proyecto: projX 10-01 in=100 out=50 (dedup: NO 200/100), projY 10-02 in=7 out=3
chk "1.projX.tok" "$(printf '%s\n' "$(jq -r .rows <<<"$J1")" | awk -F'\t' '$1=="projX"{print $3","$4}')" "100,50"
chk "1.projY.tok" "$(printf '%s\n' "$(jq -r .rows <<<"$J1")" | awk -F'\t' '$1=="projY"{print $3","$4}')" "7,3"

# ── Run 2 (caché CALIENTE, sin cambios): escanea 0 y da EL MISMO resultado ──
J2="$(run)"
chk "2.scanned-0" "$(scanned)" "0"
chk "2.igual"     "$(jq -S . <<<"$J2")" "$(jq -S . <<<"$J1")"

# ── Run 3 (un archivo CAMBIA): escanea SOLO ese 1 y el agregado se actualiza ──
cat >> "$PROJ/fb/s2.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-03T20:00:00Z","cwd":"/Users/u/code/projY"}
EOF
J3="$(run)"
chk "3.scanned-1"  "$(scanned)" "1"
chk "3.messages"   "$(jq -r .messages <<<"$J3")" "5"   # +1
chk "3.dm.10-03"   "$(jq -r '.day_msg["2026-10-03"]' <<<"$J3")" "1"

# ── Run 4 (un archivo DESAPARECE): su aporte se retira del agregado ──
rm -f "$PROJ/fa/s1.jsonl"
J4="$(run)"
chk "4.sessions"   "$(jq -r .sessions <<<"$J4")" "1"
chk "4.messages"   "$(jq -r .messages <<<"$J4")" "2"   # solo fb (L4 + nueva)
chk "4.dm.10-01-ausente" "$(jq -r '.day_msg["2026-10-01"] // "null"' <<<"$J4")" "null"

echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
