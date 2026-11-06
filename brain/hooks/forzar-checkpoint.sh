#!/usr/bin/env bash
# forzar-checkpoint.sh — Stop hook. Al CRUZAR el CRIT_PCT (92%) de GOV (el punto REAL de compact) detona UNA
# vez: decision:block que ORDENA correr /checkpoint COMPLETO + systemMessage VISIBLE para el usuario + sonido
# en la Mac. Convierte el aviso PASIVO de aviso-contexto (additionalContext, que un master metido en su tarea
# ignora) en un FRENO del cierre del turno que el usuario SÍ ve.
#
# CONTRATO (decisión de unjordi 2026-11-06): al cruzar el 92% detona SIN condiciones — NO verifica que el hilo
# se haya escrito, NO tiene tope, NO hace loop. El debounce por-CRUCE (no detona 2× el mismo cruce) es lo que
# evita el loop de Stop; re-arma cuando ctx baja tras un compact. Debajo del 92% → nada.
#
# Mide con la MISMA lib que aviso-contexto (medir-contexto.sh) → las dos mediciones no pueden divergir. STAMP
# PROPIO (si compartiera el de aviso-contexto, el PostToolUse cruzaría primero y el Stop creería «ya detonado»
# → nunca bloquearía). Solo el hilo PRINCIPAL. Fail-open silencioso sin jq/transcript/usage/ventana (igual que
# aviso-contexto: sin medición no se puede saber si estás al 92% → bloquear a ciegas sería peor).
set -u
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -n "${tp:-}" ] && [ -f "$tp" ]; } || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0                           # repo sin el sistema de memoria → no incumbe

# shellcheck source=estado-cerebro-comun.sh
. "$(dirname "$0")/estado-cerebro-comun.sh" 2>/dev/null
STATE="$(cortex_state_dir "$ROOT" 2>/dev/null)"
[ -n "$STATE" ] || STATE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/$(printf '%s' "$ROOT" | cksum 2>/dev/null | awk '{print $1}')"
mkdir -p "$STATE" 2>/dev/null || true

# Stamp de debounce POR SESIÓN (poda >14d). Fallback retro-compat sin session_id.
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null | tr -c 'A-Za-z0-9_-' '_')
FCK_F="$STATE/.forzar-checkpoint"
FCK_D="$STATE/.forzar-checkpoint.d"
if [ -n "$sid" ] && mkdir -p "$FCK_D" 2>/dev/null; then
  find "$FCK_D" -type f -mtime +14 -delete 2>/dev/null || true
  FCK_F="$FCK_D/$sid"
fi

# MEDICIÓN compartida (fuente ÚNICA con aviso-contexto). return 1 = fail-open (sin usage/ventana) → silencio.
# shellcheck source=medir-contexto.sh
. "$(dirname "$0")/medir-contexto.sh" 2>/dev/null
command -v mc_medir >/dev/null 2>&1 || exit 0
mc_medir "$tp" "$ROOT" || exit 0
[ "$mc_gov" -gt 0 ] 2>/dev/null || exit 0

CRIT_PCT="${AVISO_CONTEXTO_CRIT_PCT:-92}"
case "$CRIT_PCT" in ''|*[!0-9]*) CRIT_PCT=92 ;; esac
pctw=$(( mc_ctx * 100 / mc_gov ))
band=0
[ "$pctw" -ge "$CRIT_PCT" ] && band=1

# Debounce por-CRUCE + re-arm: el stamp guarda la última banda. Detona SOLO al SUBIR a banda 1 (last_band 0 →
# 1). Ya en banda 1 (mismo cruce) → no detona (corta el loop de Stop). Al bajar ctx tras un compact (band 0) el
# stamp vuelve a 0 → el próximo cruce re-detona. El stamp se escribe SIEMPRE (también debajo) para el re-arm.
last_band=0
if [ -f "$FCK_F" ]; then
  read -r last_band < "$FCK_F" 2>/dev/null || true
  case "${last_band:-}" in ''|*[!0-9]*) last_band=0 ;; esac
fi
printf '%s\n' "$band" > "$FCK_F" 2>/dev/null || true

{ [ "$band" = 1 ] && [ "$last_band" = 0 ]; } || exit 0   # no es un CRUCE nuevo → silencio (sin loop)

# ── CRUCE del 92%: detona UNA vez ──
govk=$(( mc_gov / 1000 ))
reason="🚨 CONTEXTO al ${pctw}% de ${govk}K (umbral ${CRIT_PCT}%). ANTES DE CUALQUIER OTRA COSA corre /checkpoint COMPLETO: vuelca el HILO a disco. El auto-compact está por dispararse y se tragaría este turno (fue lo que pasó: un /checkpoint tecleado tarde se perdió). No sigas con la tarea hasta haber hecho el checkpoint de este tramo."

# Sonido en la Mac (fuera de 22:00-08:00), best-effort y DESPRENDIDO (no cuelga el Stop). En la Mac
# aviso-claude.sh; desde otra máquina (cachy) el chime enruta a la Mac. Sin esos scripts → no-op silencioso.
_hora=$(date +%H 2>/dev/null); case "$_hora" in ''|*[!0-9]*) _hora=12 ;; esac
if [ "$_hora" -ge 8 ] && [ "$_hora" -lt 22 ]; then
  _lbl="$(basename "$ROOT" 2>/dev/null) · contexto ${CRIT_PCT}% — haz /checkpoint"
  ( "$HOME/code/PowerScripts/macos/aviso-claude.sh" "$_lbl" >/dev/null 2>&1 \
    || CHIME_TEXTO="$_lbl" "$HOME/.claude/bin/chime" >/dev/null 2>&1 ) </dev/null >/dev/null 2>&1 &
fi

jq -n --arg r "$reason" '{decision:"block", reason:$r, systemMessage:$r}'
exit 0
