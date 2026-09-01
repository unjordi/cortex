#!/usr/bin/env bash
# aviso-contexto.sh — PostToolUse hook (tier GLOBAL). Surface datos crudos de contexto.
#
# PRINCIPIO RECTOR (unjordi): el hook es un REPORTERO TONTO de datos, NO un juez.
# Emite los hechos crudos que el LLM no puede ver a mitad de corrida y deja que /context + el LLM
# decidan cuándo compactar. SIN lógica "lista" (bandas de urgencia, veredictos, derivaciones frágiles).
#
# Métrica = TOKENS REALES de contexto. El transcript trae el conteo exacto en el ÚLTIMO `usage`:
#   ctx = input_tokens + cache_creation_input_tokens + cache_read_input_tokens   (NO output_tokens).
#
# Datos que surface:
#   - ctx actual (tokens del último usage — ese cálculo ya es correcto, consérvalo).
#   - autoCompactWindow LEÍDO de settings.json (user < proyecto < local; jq '.autoCompactWindow');
#     si no está, reporta "no seteado".
#   - ventana detectada (marcador [1m] / modelos 1M-nativos / default 200K) CON auto-corrección
#     por invariante físico (si ctx > ventana → 1M). Repórtala.
#   - CLAUDE_AUTOCOMPACT_PCT_OVERRIDE si está en la env (o "no seteado" — NO inventes 92).
#
# Debounce: solo avisa al SUBIR de contexto (no en cada tool-call). Marca .contexto-aviso guarda
# el último ctx visto; si el ctx baja (hubo compact / sesión nueva) se re-arma sola.
#
# Fail-open: sin jq, sin transcript, sin memoria del repo, sin `usage`, o cualquier error → exit 0
# sin ruido. Genérico y stack-agnóstico → se instala GLOBAL (install-brain.sh).
set -u

command -v jq >/dev/null 2>&1 || exit 0        # sin jq → fail-open silencioso

input=$(cat 2>/dev/null || true)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -n "${tp:-}" ] && [ -f "$tp" ]; } || exit 0 # sin transcript → nada que medir

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0                          # repo sin el sistema de memoria → no incumbe
AVISO_F="$MEM/.contexto-aviso"

# Tokens de contexto ACTUALES = último `usage` del transcript (excluye subagentes/sidechain).
ctx=$(tail -n 400 "$tp" 2>/dev/null | jq -rR '
    fromjson? | select(.isSidechain != true) | (.message.usage // empty)
    | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
  ' 2>/dev/null | tail -1 | tr -cd '0-9')
[ -n "$ctx" ] || exit 0                          # sin usage aún → nada que medir (fail-open)

# Ventana: override explícito `AVISO_CONTEXTO_WINDOW_TOKENS`, o derivada del modelo.
# La ventana de 1M se detecta de DOS formas: (a) marcador "[1m]" en el id, (b) modelos 1M-NATIVOS
# (opus-4-7/4-8/5, sonnet-5, fable-5, mythos-5). Precedencia settings: user < proyecto < local.
WINDOW="${AVISO_CONTEXTO_WINDOW_TOKENS:-}"
case "$WINDOW" in
  ''|*[!0-9]*)
    model=""
    for s in "$HOME/.claude/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
      [ -f "$s" ] || continue
      m=$(jq -r '.model // empty' "$s" 2>/dev/null)
      [ -n "$m" ] && model="$m"
    done
    case "$model" in
      *'[1m]'*)                                                      WINDOW=1000000 ;;
      *opus-4-7*|*opus-4-8*|*opus-5*|*sonnet-5*|*fable-5*|*mythos-5*) WINDOW=1000000 ;;
      *)                                                             WINDOW=200000  ;;
    esac
    ;;
esac
# AUTO-CORRECCIÓN por invariante FÍSICO: si ctx > ventana detectada, promueve a 1M.
[ "$ctx" -gt "$WINDOW" ] 2>/dev/null && WINDOW=1000000

# autoCompactWindow: leído de settings.json (user < proyecto < local).
ACW="no seteado"
for s in "$HOME/.claude/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
  [ -f "$s" ] || continue
  acw=$(jq -r '.autoCompactWindow // empty' "$s" 2>/dev/null)
  [ -n "$acw" ] && ACW="$acw"
done

# CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: reporta crudo (no inventes 92).
PCT_OVERRIDE="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-no seteado}"

# Debounce GRUESO por PASOS de 50K tokens: emite solo al CRUZAR un nuevo escalón de contexto, NO en cada
# tool-call (con `ctx > last_ctx` a secas dispararía casi siempre — el ctx sube monótono → ruido). Al
# compactar (ctx baja) el escalón baja → last_step > step → se re-arma solo para la próxima subida.
STEP=50000
step=$(( ctx / STEP ))
last_step=0
if [ -f "$AVISO_F" ]; then
  read -r last_step < "$AVISO_F" 2>/dev/null || true
  case "${last_step:-}" in ''|*[!0-9]*) last_step=0;; esac
fi
printf '%s\n' "$step" > "$AVISO_F" 2>/dev/null || true
[ "$step" -gt "$last_step" ] || exit 0

# ── Mensaje neutro: datos crudos + recordatorio del orden checkpoint→compact ──────────────────
ctxk=$(( ctx / 1000 ))
wink=$(( WINDOW / 1000 ))
pctw=$(( ctx * 100 / WINDOW ))
freew=$(( 100 - pctw ))

msg="📊 Contexto: ${ctxk}K tokens (~${pctw}% de tu ventana ${wink}K, ${freew}% libre). "
msg="${msg}autoCompactWindow: ${ACW}. "
msg="${msg}CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: ${PCT_OVERRIDE}. "
msg="${msg}Ventana detectada: ${wink}K. "
msg="${msg}Recordatorio: si compactas, primero corre \`checkpoint\` (vuelca el hilo fresco), luego /compact. El LLM y /context deciden cuándo."

jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
