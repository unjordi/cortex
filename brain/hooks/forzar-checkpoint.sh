#!/usr/bin/env bash
# forzar-checkpoint.sh — Stop hook. Al CRUZAR el CRIT_PCT (92%) de GOV (el punto REAL de compact) frena el
# cierre del turno (decision:block) con la orden de invocar la skill checkpoint + systemMessage VISIBLE para el
# usuario + sonido en la Mac. Convierte el aviso PASIVO de aviso-contexto (additionalContext, que un master metido en su tarea
# ignora) en un FRENO del cierre del turno que el usuario SÍ ve.
#
# CONTRATO: al cruzar el 92% frena, y sigue frenando en cada Stop hasta que el transcript, DESPUÉS del primer
# freno, muestre la skill checkpoint invocada (tool_use Skill con skill=checkpoint, o el /checkpoint tecleado) o
# un /compact. Editar el hilo o appendear a la bitácora no cuenta. Tope: FORZAR_CHECKPOINT_MAX_FRENOS (3) frenos
# seguidos sin eso → avisa sin frenar, para no encerrar la sesión. Debajo del 92% → nada y se re-arma.
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

# Estado por sesión: «banda frenos línea» (línea = largo del transcript en el primer freno de este cruce;
# frenos = cuántos van; frenos=0 en banda 1 = cruce ya atendido).
read -r last_band frenos linea < "$FCK_F" 2>/dev/null || true
case "${last_band:-}" in ''|*[!0-9]*) last_band=0 ;; esac
case "${frenos:-}" in ''|*[!0-9]*) frenos=0 ;; esac
case "${linea:-}" in ''|*[!0-9]*) linea=0 ;; esac

MAX_FRENOS="${FORZAR_CHECKPOINT_MAX_FRENOS:-3}"
case "$MAX_FRENOS" in ''|*[!0-9]*|0) MAX_FRENOS=3 ;; esac

if [ "$band" = 0 ]; then printf '0 0 0\n' > "$FCK_F" 2>/dev/null; exit 0; fi

if [ "$last_band" = 1 ]; then
  [ "$frenos" -gt 0 ] || exit 0                    # este cruce ya quedó atendido
  # ¿Desde el primer freno se invocó la skill checkpoint o hubo un /compact?
  if tail -n +"$((linea + 1))" "$tp" 2>/dev/null | jq -e -s '
       any(.[];
         (.isCompactSummary == true)
         or (.type == "assistant" and ([.message.content[]? | select(.type == "tool_use" and .name == "Skill")
               | .input.skill // "" | select(. == "checkpoint" or endswith(":checkpoint"))] | length > 0))
         or (.type == "user" and ((.message.content | if type == "string" then . else ([.[]? | .text? // empty] | join(" ")) end)
               | test("<command-name>/checkpoint</command-name>"))))' >/dev/null 2>&1; then
    printf '1 0 0\n' > "$FCK_F" 2>/dev/null; exit 0
  fi
  if [ "$frenos" -ge "$MAX_FRENOS" ]; then
    printf '1 0 0\n' > "$FCK_F" 2>/dev/null
    msg="⚠️ forzar-checkpoint: ${frenos} frenos sin que se invocara la skill checkpoint; dejo de frenar este cruce. Contexto al ${pctw}%."
    jq -n --arg m "$msg" '{systemMessage:$m}'
    exit 0
  fi
  frenos=$((frenos + 1))
else
  frenos=1
  linea=$(wc -l < "$tp" 2>/dev/null | tr -d ' '); case "$linea" in ''|*[!0-9]*) linea=0 ;; esac
fi
printf '1 %s %s\n' "$frenos" "$linea" > "$FCK_F" 2>/dev/null || true

govk=$(( mc_gov / 1000 ))
reason="🚨 CONTEXTO al ${pctw}% de ${govk}K (umbral ${CRIT_PCT}%), freno ${frenos} de ${MAX_FRENOS}. ANTES DE CUALQUIER OTRA COSA invoca la skill checkpoint (Skill tool, skill=checkpoint, COMPLETO). Editar el hilo o la bitácora a mano no cuenta: este freno se repite hasta que la skill aparezca en el transcript."

# Sonido en la Mac (fuera de 22:00-08:00), best-effort y DESPRENDIDO (no cuelga el Stop). En la Mac
# aviso-claude.sh; desde otra máquina (cachy) el chime enruta a la Mac. Sin esos scripts → no-op silencioso.
_hora=$(date +%H 2>/dev/null); case "$_hora" in ''|*[!0-9]*) _hora=12 ;; esac
if [ "$frenos" = 1 ] && [ "$_hora" -ge 8 ] && [ "$_hora" -lt 22 ]; then
  _lbl="$(basename "$ROOT" 2>/dev/null) · contexto ${CRIT_PCT}% — haz /checkpoint"
  ( "$HOME/code/PowerScripts/macos/aviso-claude.sh" "$_lbl" >/dev/null 2>&1 \
    || CHIME_TEXTO="$_lbl" "$HOME/.claude/bin/chime" >/dev/null 2>&1 ) </dev/null >/dev/null 2>&1 &
fi

jq -n --arg r "$reason" '{decision:"block", reason:$r, systemMessage:$r}'
exit 0
