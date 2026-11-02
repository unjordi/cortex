#!/usr/bin/env bash
# cortex-fetch (macOS): agregados de transcripts INCREMENTALES por archivo.
# Verifica el PROPÓSITO (no la plomería) sobre un fixture de contenido conocido:
#  - MESSAGES = líneas assistant|user (con o sin ts); PEAK = TODAS las líneas con
#    ts (incl. no-msg como summary); DAY_MSG = assistant|user con ts, por día LOCAL;
#    tokens por proyecto con dedup de msg_id, colapso de cwd bajo .claude/worktrees,
#    bucket /tmp -> soloTmp, fallback de nombre al slug de la carpeta.
#  - el caché por archivo re-escanea SOLO lo nuevo/cambiado (no los GB completos).
# Los valores esperados (offset 0) son los que PRODUCE el código viejo: verificado
# one-time con una corrida COMPLETA vieja-vs-nueva sobre este mismo fixture (HOME de
# fixture + ccusage falso) -> campos de stats.json idénticos ("fiel al código viejo").
# Falla contra el código viejo: no existía el subcomando ni el caché incremental.
# HOME se aísla a la fixture (ninguna versión toca ~/.claude real). Solo macOS (BSD stat).
set -uo pipefail
FETCH="$(cd "$(dirname "$0")/../bin" && pwd)/cortex-fetch"
[[ -x "$FETCH" ]] || { echo "no encuentro cortex-fetch en $FETCH"; exit 2; }

PASS=0; FAIL=0
chk(){ local lbl="$1" got="$2" exp="$3"; if [[ "$got" == "$exp" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ $lbl: got[$got] exp[$exp]"; fi; }

SB="$(mktemp -d)"; CACHE="$SB/cache"; PROJ="$SB/hm/.claude/projects"
mkdir -p "$CACHE" "$PROJ/fa" "$PROJ/fb" "$PROJ/fc"
trap 'rm -rf "$SB"' EXIT

# Fixture determinista (offset 0 => día/hora UTC):
# fa: user 09 (projX) · assistant 09 msg_A1 (cwd bajo .claude/worktrees -> colapsa a projX, in100 out50)
#     · DUPLICADO de msg_A1 (bloque de contenido repetido: cuenta como mensaje, NO re-suma tokens)
#     · summary 23 (NO es mensaje, pero SÍ cuenta para PEAK por tener ts) · user SIN ts (mensaje, no ts).
cat > "$PROJ/fa/s1.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-01T09:00:00Z","cwd":"/srv/u/code/projX"}
{"type":"assistant","timestamp":"2026-10-01T09:30:00Z","message":{"id":"msg_A1","usage":{"input_tokens":100,"output_tokens":50}},"cwd":"/srv/u/code/projX/.claude/worktrees/wt1"}
{"type":"assistant","timestamp":"2026-10-01T09:31:00Z","message":{"id":"msg_A1","usage":{"input_tokens":100,"output_tokens":50}},"cwd":"/srv/u/code/projX"}
{"type":"summary","timestamp":"2026-10-01T23:30:00Z"}
{"type":"user","cwd":"/srv/u/code/projX"}
EOF
# fb: assistant 15 msg_B1 (projY, 7/3) + assistant 23 msg_B2 (cwd /private/tmp -> soloTmp; el nombre de la
#     carpeta sale de projY de B1, y los tokens de AMBOS se suman bajo esa carpeta).
cat > "$PROJ/fb/s2.jsonl" <<'EOF'
{"type":"assistant","timestamp":"2026-10-02T15:00:00Z","message":{"id":"msg_B1","usage":{"input_tokens":7,"output_tokens":3}},"cwd":"/srv/u/code/projY"}
{"type":"assistant","timestamp":"2026-10-02T23:45:00Z","message":{"id":"msg_B2","usage":{"input_tokens":5,"output_tokens":1}},"cwd":"/private/tmp/efimero"}
EOF
# fc: user 02 + assistant 02 msg_C1 (SIN cwd -> nombre = último segmento del slug de la carpeta: "fc").
cat > "$PROJ/fc/s3.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-03T02:00:00Z"}
{"type":"assistant","timestamp":"2026-10-03T02:05:00Z","message":{"id":"msg_C1","usage":{"input_tokens":9,"output_tokens":9}}}
EOF

# run(): HOME aislado a la fixture (ninguna versión toca ~/.claude real), caché aislado, offset 0.
run(){ env HOME="$SB/hm" CLAUDE_CONFIG_DIR= CORTEX_FETCH_CACHE_DIR="$CACHE" bash "$FETCH" --transcript-stats-json "$PROJ" 0 2>/dev/null; }
scanned(){ cat "$CACHE/.transcripts.lastscan" 2>/dev/null; }
projtok(){ printf '%s\n' "$1" | awk -F'\t' -v p="$2" '$1==p{print $3","$4}'; }

# ── Run 1 (caché FRÍO): escanea los 3 (no 0 — el bug empty-first-file) + valores exactos ──
J1="$(run)"
chk "1.scanned"  "$(scanned)" "3"
chk "1.sessions" "$(jq -r .sessions <<<"$J1")" "3"
chk "1.messages" "$(jq -r .messages <<<"$J1")" "8"      # 4 (fa: user,asst,asst-dup,user-sin-ts) +2 +2; summary NO
chk "1.peak"     "$(jq -r .peak <<<"$J1")" "9"          # hora 09 (3 líneas con ts) es la pico
chk "1.dm.10-01" "$(jq -r '.day_msg["2026-10-01"]' <<<"$J1")" "3"
chk "1.dm.10-02" "$(jq -r '.day_msg["2026-10-02"]' <<<"$J1")" "2"   # B1 + B2 (ambos assistant con ts)
chk "1.dm.10-03" "$(jq -r '.day_msg["2026-10-03"]' <<<"$J1")" "2"
R1="$(jq -r .rows <<<"$J1")"
chk "1.projX" "$(projtok "$R1" projX)" "100,50"         # dedup: NO 200/100; worktree colapsa a projX
chk "1.projY" "$(projtok "$R1" projY)" "12,4"           # B1(7/3)+B2(5/1) sumados en la carpeta fb (nombre projY)
chk "1.fc"    "$(projtok "$R1" fc)"    "9,9"            # sin cwd -> nombre = slug "fc"

# ── Run 2 (caché CALIENTE, sin cambios): escanea 0 y da EL MISMO resultado ──
J2="$(run)"
chk "2.scanned-0" "$(scanned)" "0"
chk "2.igual"     "$(jq -S . <<<"$J2")" "$(jq -S . <<<"$J1")"

# ── Run 3 (un archivo CAMBIA): escanea SOLO ese 1 y el agregado se actualiza ──
cat >> "$PROJ/fc/s3.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-03T05:00:00Z"}
EOF
J3="$(run)"
chk "3.scanned-1" "$(scanned)" "1"
chk "3.messages"  "$(jq -r .messages <<<"$J3")" "9"    # +1
chk "3.dm.10-03"  "$(jq -r '.day_msg["2026-10-03"]' <<<"$J3")" "3"

# ── Run 4 (un archivo DESAPARECE): su aporte se retira del agregado ──
rm -f "$PROJ/fa/s1.jsonl"
J4="$(run)"
chk "4.sessions"  "$(jq -r .sessions <<<"$J4")" "2"
chk "4.messages"  "$(jq -r .messages <<<"$J4")" "5"    # 8 - 4(fa) + 1(run3) = 5
chk "4.10-01-ausente" "$(jq -r '.day_msg["2026-10-01"] // "null"' <<<"$J4")" "null"
chk "4.projX-ausente" "$(projtok "$(jq -r .rows <<<"$J4")" projX)" ""

# ── Run 5: DEDUP POR CARPETA (no por archivo). Una sesión forkeada/continuada copia
#    historia con los MISMOS msg_id a otro .jsonl de la MISMA carpeta → sus tokens se
#    cuentan UNA vez (como el código viejo, que deduplicaba con un seen[] compartido por
#    carpeta). Dedup por archivo los contaría doble → este caso FALLA contra cabe96d. ──
mkdir -p "$PROJ/gg"
cat > "$PROJ/gg/g1.jsonl" <<'EOF'
{"type":"assistant","timestamp":"2026-10-05T10:00:00Z","message":{"id":"msg_G1","usage":{"input_tokens":20,"output_tokens":10}},"cwd":"/srv/u/code/projG"}
EOF
cat > "$PROJ/gg/g2.jsonl" <<'EOF'
{"type":"assistant","timestamp":"2026-10-05T10:00:00Z","message":{"id":"msg_G1","usage":{"input_tokens":20,"output_tokens":10}},"cwd":"/srv/u/code/projG"}
{"type":"assistant","timestamp":"2026-10-05T11:00:00Z","message":{"id":"msg_G2","usage":{"input_tokens":3,"output_tokens":1}},"cwd":"/srv/u/code/projG"}
EOF
J5="$(run)"
chk "5.projG-dedup-carpeta" "$(projtok "$(jq -r .rows <<<"$J5")" projG)" "23,11"   # G1 (20/10) UNA vez + G2 (3/1)

# ── Run 6: un archivo que solo CRECE (transcript de una sesión abierta) se lee desde el offset:
#    solo los bytes añadidos, y el agregado es idéntico al de una lectura completa en frío. ──
frio(){ local c; c="$(mktemp -d)"; env HOME="$SB/hm" CLAUDE_CONFIG_DIR= CORTEX_FETCH_CACHE_DIR="$c" bash "$FETCH" --transcript-stats-json "$PROJ" 0 2>/dev/null; rm -rf "$c"; }
lastbytes(){ cat "$CACHE/.transcripts.lastbytes" 2>/dev/null; }
ADD='{"type":"assistant","timestamp":"2026-10-05T12:00:00Z","message":{"id":"msg_G1","usage":{"input_tokens":20,"output_tokens":10}},"cwd":"/srv/u/code/projG"}
{"type":"assistant","timestamp":"2026-10-05T13:00:00Z","message":{"id":"msg_G3","usage":{"input_tokens":4,"output_tokens":2}},"cwd":"/srv/u/code/projG"}'
printf '%s\n' "$ADD" >> "$PROJ/gg/g2.jsonl"
J6="$(run)"
chk "6.scanned-1"      "$(scanned)" "1"
chk "6.solo-lo-nuevo"  "$(lastbytes)" "$(( ${#ADD} + 1 ))"
chk "6.projG"          "$(projtok "$(jq -r .rows <<<"$J6")" projG)" "27,13"   # G1 sigue contando UNA vez; +G3
chk "6.igual-a-frio"   "$(jq -S . <<<"$J6")" "$(frio | jq -S .)"

# ── Run 7: una línea a medio escribir (sin "\n") no se cuenta ni avanza el offset; al
#    completarse se cuenta UNA vez. ──
P1='{"type":"user","timestamp":"2026-10-05T14:00:00Z",'
printf '%s' "$P1" >> "$PROJ/gg/g2.jsonl"
J7a="$(run)"
chk "7.parcial-no-cuenta" "$(jq -r .messages <<<"$J7a")" "$(jq -r .messages <<<"$J6")"
chk "7.parcial-0-bytes"   "$(lastbytes)" "0"
printf '%s\n' '"cwd":"/srv/u/code/projG"}' >> "$PROJ/gg/g2.jsonl"
J7b="$(run)"
chk "7.completa-cuenta-1" "$(jq -r .messages <<<"$J7b")" "$(( $(jq -r .messages <<<"$J6") + 1 ))"
chk "7.igual-a-frio"      "$(jq -S . <<<"$J7b")" "$(frio | jq -S .)"

# ── Run 8: si el INICIO del archivo cambia (reescritura) y además crece, se lee completo. ──
{ printf '%s\n' '{"type":"user","timestamp":"2026-10-06T08:00:00Z","cwd":"/srv/u/code/projG"}'; cat "$PROJ/gg/g2.jsonl"; } > "$SB/g2.new"
mv "$SB/g2.new" "$PROJ/gg/g2.jsonl"
J8="$(run)"
chk "8.lectura-completa" "$(lastbytes)" "$(stat -f %z "$PROJ/gg/g2.jsonl")"
chk "8.igual-a-frio"     "$(jq -S . <<<"$J8")" "$(frio | jq -S .)"

echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
