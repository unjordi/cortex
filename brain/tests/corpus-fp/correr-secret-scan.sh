#!/usr/bin/env bash
# correr-secret-scan.sh — banco del corpus para secret-scan (DENY). Fixture = repo con archivo staged / commit por empujar.
# Corre con `bash brain/tests/corpus-fp/correr-secret-scan.sh`.
# Los secretos de los controles+ se arman en runtime por concatenación (este archivo se commitea y el propio
# guard lo escanea). L175 es una nota de "tuning aplicado" (no un caso FP): sin comando que reproducir.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
GUARD="$HOOKS/secret-scan.sh"
export CFP_MODE=deny

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-ss.XXXXXX"); BARE="$ROOT/o.git"; R="$ROOT/repo"
g() { git -C "$R" "$@" >/dev/null 2>&1; }
git init -q --bare "$BARE"; git init -q -b develop "$R"; g config user.email t@t; g config user.name t
g remote add origin "$BARE"; printf 'base\n' > "$R/base.txt"; g add .; g commit -q -m base; g push -q origin develop

PW="Pass""word"; AK="AKIA""Z7Q2M5N8R3T6W9XB"; SK="sk-ant-""api03-Zq81xKd92LmNv7TyRw3PaEh5JcUb40GfS"
reset_stage() { g reset -q --hard HEAD; g clean -fdq; }

echo "== secret-scan · banco del corpus (FP esperan PASAR; controles+ esperan FRENAR) =="

# L133: relleno de prueba en un test (commit)
mkdir -p "$R/scripts/tests"
printf '# aquí va uno de PRUEBA inventado\nINI = "[Conexion]\\n%s=PRUEBA-no-real\\n"\n' "$PW" > "$R/scripts/tests/test_config.py"
g add .
cfp_caso "$GUARD" 133 "$PW=PRUEBA-no-real en un test (commit)" 'git commit -m "test: config"' "$R" pass
reset_stage

# L172: placeholder citado en una TABLA de un doc de auditoría (commit)
mkdir -p "$R/docs"
printf '| caso | valor |\n|---|---|\n| FP | %s=PRUEBA-no-real |\n' "$PW" > "$R/docs/auditoria-tests.md"
g add .
cfp_caso "$GUARD" 172 "$PW=PRUEBA-no-real citado en doc de auditoría (commit)" 'git commit -m "docs: auditoria"' "$R" pass
reset_stage

# L180: el PROPIO corpus cita el patrón; se empuja la ramita (push, rama nueva sin upstream)
g checkout -q -b docs/afinado; mkdir -p "$R/docs"
printf -- '- 2026-09-10 · secret-scan · "%s=PRUEBA-no-real" en un test · era relleno\n' "$PW" > "$R/docs/guards-falsos-positivos.md"
g add .; g commit -q -m "docs: corpus"
cfp_caso "$GUARD" 180 "push de ramita cuyo commit CITA $PW=PRUEBA-no-real (corpus)" 'git push -u origin docs/afinado' "$R" pass
g checkout -q develop; g branch -q -D docs/afinado

# ── CONTROLES POSITIVOS (DEBEN frenar) ──
printf 'cfg\n%s=Xk39sjdh2zz81\n' "$PW" > "$R/app.ini"; g add .
cfp_caso "$GUARD" - "ctrl+ $PW=<valor real> en commit" 'git commit -m "x"' "$R" block
reset_stage
printf 'k=%s\n' "$AK" > "$R/aws.env"; g add .
cfp_caso "$GUARD" - "ctrl+ llave AWS AKIA en commit" 'git commit -m "x"' "$R" block
reset_stage
printf 'export K=%s\n' "$SK" > "$R/k.sh"; g add .
cfp_caso "$GUARD" - "ctrl+ token sk-ant en commit" 'git commit -m "x"' "$R" block
reset_stage
g checkout -q -b feat/leak; printf 'k=%s\n' "$AK" > "$R/leak.env"; g add .; g commit -q -m leak
cfp_caso "$GUARD" - "ctrl+ push de ramita con llave AWS" 'git push -u origin feat/leak' "$R" block

cfp_reporte secret-scan
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
