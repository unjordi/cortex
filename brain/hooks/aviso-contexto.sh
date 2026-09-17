#!/usr/bin/env bash
# aviso-contexto.sh — PostToolUse hook (tier GLOBAL). El HUB que PROTEGE el hilo al acercarse el compact.
#
# PRINCIPIO RECTOR (unjordi, REVISIÓN 2026-09-17): el hook HACE trabajo real, no reporta cada 5%. La
# auditoría lo dictó: los hooks que solo AVISAN se ignoran; el único con tracción es el que EJECUTA. Este
# hook deja de gotear cada escalón y de deferir la decisión ("tú decides"). Ahora:
#   1. GUARDA SILENCIO total por debajo del umbral ALTO — nada de reporte por-5%.
#   2. Al CRUZAR el umbral ALTO (cerca del punto REAL de compact) EJECUTA solito el checkpoint MECÁNICO
#      (vuelca el andamio del hilo/estado/git a disco, CERO tokens de modelo) y emite UNA línea en tono de
#      ORDEN. Una sola escalada más (umbral CRÍTICO) si el contexto sigue subiendo peligrosamente.
#   3. NÚMEROS HONESTOS: el denominador es el punto REAL de compact — autoCompactWindow si está seteado y
#      el auto-compact ACTIVO; si no, la ventana efectiva del modelo. Si autoCompactEnabled=false NO miente
#      diciendo "el auto-compact dispara al llenarse la ventana": dice la verdad (auto-compact APAGADO → el
#      corte lo decides tú / compact manual).
#
# El checkpoint EN PROSA (el juicio: en qué estamos, decisión abierta, siguiente paso) sigue necesitando
# al modelo — este hook corre la RED MECÁNICA que va sola, no la reemplaza. Por eso la orden empuja al
# lector a correr /checkpoint (prosa) + /compact, además del andamio ya volcado.
#
# Métrica = TOKENS REALES de contexto, del ÚLTIMO `usage`, ANCLADA al último /compact (un
# `isCompactSummary:true` resetea el acumulado → no se reporta el tamaño VIEJO pre-compact como si fuera
# el contexto vivo). ctx = input + cache_creation + cache_read (NO output).
#
# Debounce por BANDA (no por escalón): 0 = bajo el umbral ALTO (silencio); 1 = cruzó ALTO; 2 = cruzó
# CRÍTICO. Solo dispara al SUBIR de banda. Al compactar (ctx baja) la banda baja → se re-arma sola.
#
# Fail-open: sin jq, sin transcript, sin memoria del repo, sin `usage`, o cualquier error → exit 0 sin
# ruido. Genérico y stack-agnóstico → se instala GLOBAL (install-brain.sh).
set -u

command -v jq >/dev/null 2>&1 || exit 0        # sin jq → fail-open silencioso

input=$(cat 2>/dev/null || true)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -n "${tp:-}" ] && [ -f "$tp" ]; } || exit 0 # sin transcript → nada que medir

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0                          # repo sin el sistema de memoria → no incumbe

# Stamp de debounce keyeado POR SESIÓN (no por repo): un stamp único por-repo hacía THRASH entre sesiones
# concurrentes. Poda best-effort >14d. Fallback retro-compat: sin session_id → el archivo único de antes.
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null | tr -c 'A-Za-z0-9_-' '_')
AVISO_F="$MEM/.contexto-aviso"
AVISO_D="$MEM/.contexto-aviso.d"
if [ -n "$sid" ] && mkdir -p "$AVISO_D" 2>/dev/null; then
  find "$AVISO_D" -type f -mtime +14 -delete 2>/dev/null || true
  AVISO_F="$AVISO_D/$sid"
fi

# Tokens de contexto ACTUALES = último `usage`, ANCLADO al último /compact. Un `isCompactSummary:true`
# RESETEA el acumulado: descarta todo usage previo al boundary (justo tras compactar, el usage grande
# PRE-compact de la llamada interna de resumen NO se cuela como "contexto vivo"). Si aún no hay usage
# DESPUÉS del boundary → null → fail-open (silencio), en vez de gritar el tamaño viejo en falso.
ctx=$(tail -n 400 "$tp" 2>/dev/null | jq -rRn '
    reduce (inputs | fromjson?) as $o (null;
        if   ($o.isCompactSummary == true) then null      # boundary de /compact → descarta lo previo
        elif ($o.isSidechain == true)      then .         # subagente → no cuenta al hilo principal
        elif ($o.message.usage)            then ($o.message.usage
              | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
        else . end)
    // empty
  ' 2>/dev/null | tr -cd '0-9')
[ -n "$ctx" ] || exit 0                          # sin usage fresco (post-compact) aún → fail-open

# Ventana del MODELO: override explícito `AVISO_CONTEXTO_WINDOW_TOKENS`, o derivada del modelo (marcador
# "[1m]" / 1M-nativos / default 200K). Precedencia settings: user < proyecto < local.
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

# autoCompactEnabled: default true; solo `false` explícito (o el env DISABLE_AUTO_COMPACT) desactiva el
# auto-compact. Precedencia user < proyecto < local; null/ausente NO override.
ac_enabled=true
for s in "$HOME/.claude/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
  [ -f "$s" ] || continue
  e=$(jq -r 'if .autoCompactEnabled == null then empty else (.autoCompactEnabled|tostring) end' "$s" 2>/dev/null)
  [ -n "$e" ] && ac_enabled="$e"
done
case "${DISABLE_AUTO_COMPACT:-}" in ''|0|false|FALSE|no|NO) : ;; *) ac_enabled=false ;; esac

# VENTANA GOBERNANTE (GOV) = el punto REAL donde compacta, contra el que se mide el %. El auto-compact
# dispara al acercarse a autoCompactWindow, NO a la ventana del modelo → el denominador es ACW cuando el
# auto-compact está ACTIVO y ACW es número válido; si no (no seteado / desactivado / override manual), la
# ventana del modelo. El override manual AVISO_CONTEXTO_WINDOW_TOKENS (ya en WINDOW) gana sobre ACW.
acw_num=""
case "$ACW" in ''|*[!0-9]*) : ;; *) [ "$ACW" -gt 0 ] 2>/dev/null && acw_num="$ACW" ;; esac
forced=""
case "${AVISO_CONTEXTO_WINDOW_TOKENS:-}" in ''|*[!0-9]*) : ;; *) forced=1 ;; esac
GOV="$WINDOW"; govsrc="model"
if [ -z "$forced" ] && [ "$ac_enabled" = "true" ] && [ -n "$acw_num" ]; then
  GOV="$acw_num"; govsrc="acw"
fi

# ── BANDA por umbral ALTO/CRÍTICO relativo a GOV (el punto REAL de compact) ─────────────────────────
# NO se gotea por-5%: silencio bajo ALTO; UN disparo al cruzar ALTO; UNA escalada al cruzar CRÍTICO. Los
# umbrales se expresan como % de GOV (el punto real), no del 1M pelón, y son ajustables por env para tests.
HIGH_PCT="${AVISO_CONTEXTO_HIGH_PCT:-80}"
CRIT_PCT="${AVISO_CONTEXTO_CRIT_PCT:-92}"
case "$HIGH_PCT" in ''|*[!0-9]*) HIGH_PCT=80 ;; esac
case "$CRIT_PCT" in ''|*[!0-9]*) CRIT_PCT=92 ;; esac

pctw=$(( ctx * 100 / GOV ))
band=0
[ "$pctw" -ge "$HIGH_PCT" ] && band=1
[ "$pctw" -ge "$CRIT_PCT" ] && band=2

last_band=0
if [ -f "$AVISO_F" ]; then
  read -r last_band < "$AVISO_F" 2>/dev/null || true
  case "${last_band:-}" in ''|*[!0-9]*) last_band=0 ;; esac
fi
printf '%s\n' "$band" > "$AVISO_F" 2>/dev/null || true

# Solo actúa al SUBIR de banda a una banda de acción (>=1). Bajo el umbral, o sin cruzar una banda nueva
# → SILENCIO TOTAL (exit 0 sin additionalContext).
{ [ "$band" -ge 1 ] && [ "$band" -gt "$last_band" ]; } || exit 0

# ── HACE: dispara el checkpoint MECÁNICO (red de seguridad automática, CERO tokens de modelo) ─────────
_selfdir="$(dirname "$0")"
if [ -f "$_selfdir/checkpoint-mecanico-comun.sh" ]; then
  # shellcheck source=checkpoint-mecanico-comun.sh
  . "$_selfdir/checkpoint-mecanico-comun.sh"
  sid_raw=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  disparar_checkpoint_mecanico "$sid_raw" "$tp" "$ROOT" "$MEM" "$_selfdir" || true
fi

# ── Mensaje: UNA línea, tono de ORDEN. El HUB manda: checkpoint mecánico HECHO + qué hacer ahora ──────
ctxk=$(( ctx / 1000 ))
govk=$(( GOV / 1000 ))
wink=$(( WINDOW / 1000 ))

# Denominador HONESTO nombrado por su fuente.
if [ "$govsrc" = "acw" ]; then
  den="autoCompactWindow ${govk}K"
else
  den="tu ventana ${govk}K"
fi

# El "corte": la VERDAD según autoCompactEnabled. Con auto-compact ACTIVO el CLI cortará al llenarse GOV;
# APAGADO, NO se afirma que dispare — el corte lo decide el lector (/compact manual).
if [ "$ac_enabled" != "true" ]; then
  corte="auto-compact APAGADO → el corte lo decides TÚ: corre /compact cuando cierres el hilo"
elif [ "$govsrc" = "acw" ]; then
  corte="el auto-compact del CLI cortará al llegar a autoCompactWindow — adelántate con /compact"
else
  corte="el auto-compact del CLI cortará al llenarse la ventana — adelántate con /compact"
fi

if [ "$band" -ge 2 ]; then
  head="🚨 Contexto ~${pctw}% de ${den} (${ctxk}K) — RAYANDO el compact."
  order="Ya volqué el andamio mecánico a hilo-mental-actual.andamio.md. CORRE /checkpoint (el hilo en prosa NECESITA modelo) y /compact YA: ${corte}."
else
  head="📊 Contexto ~${pctw}% de ${den} (${ctxk}K) — cerca del compact."
  order="Volqué el andamio mecánico a hilo-mental-actual.andamio.md. Haz /checkpoint (el hilo en prosa NECESITA modelo) y considera /compact: ${corte}."
fi

# Dato extra sin mentir: cuando GOV = autoCompactWindow, la ventana del modelo va como referencia; cuando
# GOV = la del modelo pero hay un ACW seteado con el auto-compact APAGADO, se aclara por qué ACW no gobierna.
extra=""
if [ "$govsrc" = "acw" ]; then
  extra=" (ventana del modelo: ${wink}K)."
elif [ "$ac_enabled" != "true" ] && [ -n "$acw_num" ]; then
  extra=" (autoCompactWindow: ${ACW}, pero el auto-compact está desactivado)."
fi

msg="${head} ${order}${extra}"
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
