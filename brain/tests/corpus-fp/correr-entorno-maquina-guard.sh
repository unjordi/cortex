#!/usr/bin/env bash
# correr-entorno-maquina-guard.sh — banco del corpus para entorno-maquina-guard (AVISO: additionalContext).
# Corre con `bash brain/tests/corpus-fp/correr-entorno-maquina-guard.sh`.
# L156/L158/L162: un commit -F- que toca SOLO scripts/ (o borra líneas) no debe avisar por un
# .claude/memory/estado-proyecto.md con "Rosetta" sin condicional que NO entra al commit. La prosa NO dice qué
# del comando activó el modo `-a/--all` (único camino por el que un archivo no-staged se evalúa): se reproduce el
# comando tal cual consta (`git commit -F-`) y se mide; la SONDA del final (no cuenta) prueba la hipótesis.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
GUARD="$HOOKS/entorno-maquina-guard.sh"
export CFP_MODE=aviso

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-emg.XXXXXX"); R="$ROOT/repo"
g() { git -C "$R" "$@" >/dev/null 2>&1; }
git init -q -b develop "$R"; g config user.email t@t; g config user.name t
mkdir -p "$R/.claude/memory" "$R/scripts"
printf '# estado\n- ok\n' > "$R/.claude/memory/estado-proyecto.md"
printf 'x\n' > "$R/scripts/deploy.ps1"
g add .; g commit -q -m base
# working tree: estado-proyecto.md modificado SIN stagear con "Rosetta" pelón; el commit solo trae scripts/
printf -- '- SQL Server corre amd64 vía Rosetta\n' >> "$R/.claude/memory/estado-proyecto.md"
printf 'y\n' >> "$R/scripts/deploy.ps1"; g add scripts/deploy.ps1

echo "== entorno-maquina-guard · banco del corpus (FP esperan SILENCIO; controles+ esperan AVISO) =="
MSG="git commit -F- <<'EOF'
fix(toolkit): deploy
EOF"
cfp_caso "$GUARD" 156 "commit -F- solo scripts/; Rosetta en archivo NO staged" "$MSG" "$R" pass
cfp_caso "$GUARD" 158 "commit -F- (wg-megaflux.md + scripts/); estado-proyecto no staged" "$MSG" "$R" pass
cfp_caso "$GUARD" 162 "commit -F- que borra líneas; Rosetta en archivo no staged" "$MSG" "$R" pass

# ── CONTROLES POSITIVOS (DEBEN avisar) ──
g add .claude/memory/estado-proyecto.md   # ahora SÍ entra al commit el Rosetta pelón
cfp_caso "$GUARD" - "ctrl+ Rosetta sin condicional STAGED en .claude/memory" 'git commit -m x' "$R" block
g reset -q .claude/memory/estado-proyecto.md
printf '# e\n' > "$R/.claude/memory/entorno-maquina.md"; g add .claude/memory/entorno-maquina.md
cfp_caso "$GUARD" - "ctrl+ filename-trampa entorno-maquina.md staged" 'git commit -m x' "$R" block
g reset -q .claude/memory/entorno-maquina.md; rm -f "$R/.claude/memory/entorno-maquina.md"
printf 'ruta /Users/%s/code/x\n' ana > "$R/.claude/memory/nota.md"; g add .claude/memory/nota.md
cfp_caso "$GUARD" - "ctrl+ ruta absoluta de \$HOME staged" 'git commit -m x' "$R" block
g reset -q .claude/memory/nota.md; rm -f "$R/.claude/memory/nota.md"

cfp_reporte entorno-maquina-guard

# SONDA (no cuenta): hipótesis — el modo -a se activa por un flag tipo -la en OTRA parte del compuesto
r=$(cfp_run_guard "$GUARD" "ls -la scripts && git commit -F- <<EOF
m
EOF" "$R")
echo "  [sonda, no cuenta] compuesto con 'ls -la' + commit -F-: $r  (DENY = dispara = FP; PASS = silencio)"
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
