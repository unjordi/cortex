#!/usr/bin/env bash
# lib-corpus-fp.sh — infraestructura del BANCO DEL CORPUS de falsos positivos.
# Convierte cada caso del corpus (docs/guards-falsos-positivos.md) en una corrida REPRODUCIBLE:
# arma el contexto (repo/rama/cwd/worktree), alimenta el comando al guard REAL y clasifica PASA/FRENA.
#
# DOS trampas que invalidan el banco si se ignoran (medidas por claudio 2026-10-19):
#  1) DEDUPE: cada guard trae `case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/<g>" ] && exit 0`.
#     Si corre la copia del REPO y existe la GLOBAL, CEDE con exit 0 SIN evaluar → verde falso.
#     Se neutraliza corriendo con HOME=<dir vacío> (sin ~/.claude/hooks/<g> → la copia del repo SÍ evalúa).
#  2) El PROPIO git-branch-guard escanea el comando Bash → un banco con `git push` literal en la línea
#     se auto-bloquea. Por eso el banco vive en SCRIPTS corridos con `bash <archivo>` (el guard ve `bash x.sh`).
#
# Controles POSITIVOS (casos que DEBEN frenar) van en cada guard: si un control positivo PASA, el harness
# está roto (verde falso) y el reporte lo grita.

set -u
: "${HOOKS:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../hooks" && pwd)}"   # brain/hooks

CFP_PASS=0 CFP_FPBLOCK=0 CFP_CTRL_OK=0 CFP_CTRL_BAD=0
CFP_FP_LINES=()        # casos de corpus que SIGUEN frenando (reportar, no borrar)
CFP_BROKEN=()          # controles positivos que no frenaron (harness roto)

# cfp_fakehome → imprime un HOME temporal vacío (sin ~/.claude/hooks) para neutralizar el dedupe.
cfp_fakehome() { local h; h=$(mktemp -d "${TMPDIR:-/tmp}/cfp-home.XXXXXX"); printf '%s' "$h"; }

# cfp_run_guard <guard.sh> <cmd> <cwd> → corre el guard con el JSON del hook; imprime "DENY" o "PASS".
# Neutraliza el dedupe (HOME falso) y pasa cwd en el payload (como el harness real).
cfp_run_guard() {
  local guard="$1" cmd="$2" cwd="${3:-}" fh out
  fh=$(cfp_fakehome)
  out=$(jq -nc --arg c "$cmd" --arg d "$cwd" '{tool_input:{command:$c},cwd:$d}' \
        | HOME="$fh" CLAUDE_PROJECT_DIR="$cwd" bash "$guard" 2>/dev/null)
  rm -rf "$fh"
  if printf '%s' "$out" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then printf 'DENY'; else printf 'PASS'; fi
}

# cfp_caso <guard.sh> <linea-corpus> <"nota corta"> <cmd> <cwd> <esperado:pass|block>
# esperado=pass → es un FP del corpus: DEBE pasar; si frena, se reporta (NO se borra del corpus).
# esperado=block → control POSITIVO: DEBE frenar; si pasa, el harness está roto (verde falso).
cfp_caso() {
  local guard="$1" linea="$2" nota="$3" cmd="$4" cwd="$5" esp="$6" r
  r=$(cfp_run_guard "$guard" "$cmd" "$cwd")
  if [ "$esp" = pass ]; then
    if [ "$r" = PASS ]; then CFP_PASS=$((CFP_PASS+1)); printf '  ✓ PASA  L%-4s %s\n' "$linea" "$nota"
    else CFP_FPBLOCK=$((CFP_FPBLOCK+1)); CFP_FP_LINES+=("L$linea: $nota"); printf '  ✗ FRENA L%-4s %s  ← FP sigue vivo\n' "$linea" "$nota"; fi
  else
    if [ "$r" = DENY ]; then CFP_CTRL_OK=$((CFP_CTRL_OK+1)); printf '  ✓ ctrl+ frena  %s\n' "$nota"
    else CFP_CTRL_BAD=$((CFP_CTRL_BAD+1)); CFP_BROKEN+=("$nota"); printf '  ⚠ ctrl+ PASÓ (harness roto / verde falso): %s\n' "$nota"; fi
  fi
}

cfp_reporte() {
  local guard="$1"
  printf '\n== CONTEO %s ==\n' "$guard"
  printf '  FP que PASAN (corregidos): %d\n' "$CFP_PASS"
  printf '  FP que SIGUEN frenando:    %d\n' "$CFP_FPBLOCK"
  printf '  controles+ OK (frenan):    %d / %d\n' "$CFP_CTRL_OK" "$((CFP_CTRL_OK+CFP_CTRL_BAD))"
  if [ "$CFP_CTRL_BAD" -gt 0 ]; then printf '  ⚠⚠ HARNESS ROTO: %d control(es)+ no frenaron (verde falso)\n' "$CFP_CTRL_BAD"; fi
  if [ "$CFP_FPBLOCK" -gt 0 ]; then printf '  FP vivos:\n'; printf '    - %s\n' "${CFP_FP_LINES[@]}"; fi
}
