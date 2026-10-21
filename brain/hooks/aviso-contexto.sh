#!/usr/bin/env bash
# aviso-contexto.sh — PostToolUse hook (tier GLOBAL). El HUB que PROTEGE el hilo al acercarse el compact.
#
# PRINCIPIO RECTOR: el hook HACE trabajo real, no reporta cada 5%. Los hooks que solo AVISAN se ignoran.
# Este hook no gotea cada escalón y de deferir la decisión ("tú decides"). Ahora:
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

# Ventana del MODELO: SOLO por EVIDENCIA — override explícito `AVISO_CONTEXTO_WINDOW_TOKENS`, marcador
# "[1m]", o un modelo con ventana real LISTADA. Modelo desconocido → NO hay ventana (silencio), NUNCA un
# default inventado. Precedencia settings: user < proyecto < local.
WINDOW="${AVISO_CONTEXTO_WINDOW_TOKENS:-}"
case "$WINDOW" in
  ''|*[!0-9]*)
    model=""
    for s in "$HOME/.claude/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
      [ -f "$s" ] || continue
      m=$(jq -r '.model // empty' "$s" 2>/dev/null)
      [ -n "$m" ] && model="$m"
    done
    # MODELO DE RUNTIME del transcript (el que REALMENTE genera) — GANA sobre settings.json. El modelo elegido
    # en runtime (p. ej. Opus 5.5) NO queda escrito en settings.json → sin esto, model="" → desconocido. El
    # transcript lo trae en .message.model (último mensaje no-sidechain). fromjson? = robusto a líneas malas.
    # SALTA modelos "<…>" (p. ej. "<synthetic>": límite de sesión / errores de API / interrupciones) para no
    # tapar el último modelo REAL anterior (un "<synthetic>" propio se leería como desconocido → silencio).
    tpm=$(tail -n 400 "$tp" 2>/dev/null | jq -rRn '
        reduce (inputs | fromjson?) as $o (null;
            if ($o.isSidechain == true) then .
            else (($o.message.model // $o.model) as $m
                  | if ($m != null and ($m | startswith("<") | not)) then $m else . end)
            end)
        // empty' 2>/dev/null)
    [ -n "$tpm" ] && model="$tpm"
    case "$model" in
      *'[1m]'*)                                                      WINDOW=1000000 ;;
      *opus-4-7*|*opus-4-8*|*opus-5*|*sonnet-5*|*fable-5*|*mythos-5*) WINDOW=1000000 ;;
      *)                                                             WINDOW="" ;;   # desconocido/vacío/<synthetic> → NO inventar ventana
    esac
    ;;
esac
# Sin ventana por EVIDENCIA (ni override, ni marcador [1m], ni modelo listado; modelo desconocido/vacío/
# <synthetic>): NO inventamos un número — fail-open SILENCIOSO, igual que sin jq/usage (no hay default de ventana).
case "$WINDOW" in ''|*[!0-9]*) exit 0 ;; esac
# AUTO-CORRECCIÓN por invariante FÍSICO: si ctx > ventana detectada (de [1m]/modelo listado), promueve a 1M.
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

# ── BANDA por umbral ALTO/CRÍTICO relativo a GOV (el punto REAL de compact) ─────────────────── ──
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

# fire_ctx: el CONTEXTO dispara al SUBIR de banda a una banda de acción (>=1). Ya NO sale temprano: la
# cuota (abajo) es una SEGUNDA causa independiente — el hook puede disparar por cuota con el contexto bajo.
fire_ctx=0
{ [ "$band" -ge 1 ] && [ "$band" -gt "$last_band" ]; } && fire_ctx=1

# ── CUOTA: segunda causa de disparo, independiente del contexto (diseño 2026-10-19) ───────────── ──
# Pone la cuota (ventana de 5h y semanal) enfrente del modelo DURANTE el trabajo — hoy solo la ven
# delegacion-gate/limite-gasto al lanzar agentes. Dispara al CRUZAR umbrales (5h 80%/95%, semanal 80%),
# una vez por umbral y por VENTANA (se re-arma cuando cambia el resets_at de esa ventana). La línea la arma
# linea_cuota (delegacion-comun.sh). Si el snapshot está rancio (>30min) o ausente: FUERZA un cortex-fetch
# DESPRENDIDO (sin heredar el stdio, H11) con throttle de 5min y espera ~5s a que cambie el mtime; si no
# cambia, calla la cuota. Sin cortex-fetch (máquina sin widget): calla la cuota, el contexto sigue igual.
# NOTA: la cuota solo se evalúa si el CONTEXTO fue medible (llegamos hasta aquí) — con modelo desconocido el
# hook ya calla del todo, como hoy; cubrir ese borde exigiría un refactor del flujo (fuera de alcance).
fire_quota=0; quota_line=""
_selfdir="$(dirname "$0")"
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo ""; }   # GNU primero; BSD de respaldo
_find_snap() { _snap=""; for _c in "${XDG_CACHE_HOME:-$HOME/.cache}/cortex/state.json" "$HOME/Library/Caches/cortex/state.json"; do [ -f "$_c" ] && { _snap="$_c"; break; }; done; }
_snap_fresca() {  # 0 = fresca (updated_at <= 30min y no stale); 1 = rancia/ausente
  [ -n "$_snap" ] || return 1
  [ "$(jq -r '.stale // false' "$_snap" 2>/dev/null)" = "true" ] && return 1
  _up=$(jq -r '.updated_at // empty' "$_snap" 2>/dev/null); [ -n "$_up" ] || return 1
  _us=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$_up" +%s 2>/dev/null || date -u -d "$_up" +%s 2>/dev/null || echo 0)
  [ "$_us" -gt 0 ] 2>/dev/null && [ $(( $(date +%s) - _us )) -le 1800 ]
}
_find_snap
if ! _snap_fresca; then
  # FORZAR cortex-fetch desprendido, con throttle de 5min (sello en MEM). El binario vive en
  # ~/.local/bin/cortex-fetch (macOS y Linux instalan ahí); override por env para tests/escape. NO se busca
  # en el PATH (evita que un hook aislado con HOME falso dispare el cortex-fetch REAL del usuario).
  fetch_bin=""
  for b in "${AVISO_CUOTA_FETCH_CMD:-}" "$HOME/.local/bin/cortex-fetch"; do
    [ -n "$b" ] && [ -x "$b" ] && { fetch_bin="$b"; break; }
  done
  force_stamp="$MEM/.cuota-fetch-forzado"; throttled=0
  if [ -f "$force_stamp" ]; then
    _fs=$(_mtime "$force_stamp"); case "$_fs" in ''|*[!0-9]*) _fs=0;; esac
    [ "$_fs" -gt 0 ] && [ $(( $(date +%s) - _fs )) -lt 300 ] && throttled=1
  fi
  if [ -n "$fetch_bin" ] && [ "$throttled" -eq 0 ]; then
    : > "$force_stamp" 2>/dev/null || true
    _before=""; [ -n "$_snap" ] && _before=$(_mtime "$_snap")
    ( "$fetch_bin" ) </dev/null >/dev/null 2>&1 &     # DESPRENDIDO: no hereda el stdio del hook (H11)
    # Esperar hasta ~5s a que el snapshot cambie de mtime: el fetch lo reescribe en ~3s, pero el proceso
    # completo (enriquecimiento ccusage) pasa de 30s → esperamos el mtime, no el proceso. El fetch sigue en
    # 2º plano aunque dejemos de esperar (está desprendido).
    _w=0
    while [ "$_w" -lt 50 ]; do
      [ -z "$_snap" ] && _find_snap
      if [ -n "$_snap" ]; then _aftr=$(_mtime "$_snap"); [ -n "$_aftr" ] && [ "$_aftr" != "$_before" ] && break; fi
      sleep 0.1; _w=$(( _w + 1 ))
    done
  fi
fi
# Con snapshot FRESCO (de origen o recién forzado), computa las bandas de cuota con debounce por ventana.
if _snap_fresca; then
  q5=$(jq -r '.five_hour.percent // empty'   "$_snap" 2>/dev/null)
  q5r=$(jq -r '.five_hour.resets_at // empty' "$_snap" 2>/dev/null)
  qw=$(jq -r '.weekly.percent // empty'      "$_snap" 2>/dev/null)
  qwr=$(jq -r '.weekly.resets_at // empty'    "$_snap" 2>/dev/null)
  if [ -n "$q5" ] && [ "$q5" -eq "$q5" ] 2>/dev/null; then
    Q5H="${AVISO_CUOTA_5H_HIGH:-80}"; Q5C="${AVISO_CUOTA_5H_CRIT:-95}"; QWH="${AVISO_CUOTA_SEM_HIGH:-80}"
    case "$Q5H" in ''|*[!0-9]*) Q5H=80;; esac; case "$Q5C" in ''|*[!0-9]*) Q5C=95;; esac; case "$QWH" in ''|*[!0-9]*) QWH=80;; esac
    b5=0; [ "$q5" -ge "$Q5H" ] && b5=1; [ "$q5" -ge "$Q5C" ] && b5=2
    bw=0; { [ -n "$qw" ] && [ "$qw" -eq "$qw" ] 2>/dev/null && [ "$qw" -ge "$QWH" ]; } && bw=1
    # Stamp de cuota: sibling del de contexto (mismo keying por sesión). "<5h_resets> <5h_band> <wk_resets> <wk_band>"
    QF="$AVISO_F.cuota"; l5r=""; l5b=0; lwr=""; lwb=0
    [ -f "$QF" ] && read -r l5r l5b lwr lwb < "$QF" 2>/dev/null || true
    case "$l5b" in ''|*[!0-9]*) l5b=0;; esac; case "$lwb" in ''|*[!0-9]*) lwb=0;; esac
    # RE-ARM por ventana: si el resets_at cambió (ventana nueva), el last_band de ESA ventana vuelve a 0.
    [ "$q5r" != "$l5r" ] && l5b=0
    [ "$qwr" != "$lwr" ] && lwb=0
    printf '%s %s %s %s\n' "$q5r" "$b5" "$qwr" "$bw" > "$QF" 2>/dev/null || true
    { [ "$b5" -ge 1 ] && [ "$b5" -gt "$l5b" ]; } && fire_quota=1
    { [ "$bw" -ge 1 ] && [ "$bw" -gt "$lwb" ]; } && fire_quota=1
    # La línea de cuota (reutiliza linea_cuota de delegacion-comun.sh) — para incluirla en el mensaje.
    if [ -f "$_selfdir/delegacion-comun.sh" ]; then
      # shellcheck source=delegacion-comun.sh
      . "$_selfdir/delegacion-comun.sh" 2>/dev/null && quota_line=$(linea_cuota 2>/dev/null)
    fi
  fi
fi

# Nada que decir por NINGUNA causa → SILENCIO TOTAL.
{ [ "$fire_ctx" -eq 1 ] || [ "$fire_quota" -eq 1 ]; } || exit 0

# ── HACE: dispara el checkpoint MECÁNICO solo si disparó el CONTEXTO (compact inminente). En un disparo de
#    cuota-sola el contexto puede estar bajo → no hay hilo que proteger todavía, no se vuelca el andamio.
if [ "$fire_ctx" -eq 1 ] && [ -f "$_selfdir/checkpoint-mecanico-comun.sh" ]; then
  # shellcheck source=checkpoint-mecanico-comun.sh
  . "$_selfdir/checkpoint-mecanico-comun.sh"
  sid_raw=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  disparar_checkpoint_mecanico "$sid_raw" "$tp" "$ROOT" "$MEM" "$_selfdir" || true
fi

# ── Mensaje: hasta DOS líneas (contexto + cuota). Dispare por lo que dispare, se incluyen AMBAS si están
#    disponibles, para que se lea qué conviene hacer. La de contexto es la ORDEN completa si disparó el
#    contexto, o un estado BREVE si solo disparó la cuota. La de cuota se incluye si hay snapshot.
ctxk=$(( ctx / 1000 ))
govk=$(( GOV / 1000 ))
wink=$(( WINDOW / 1000 ))

# Denominador HONESTO nombrado por su fuente.
if [ "$govsrc" = "acw" ]; then
  den="autoCompactWindow ${govk}K"
else
  den="tu ventana ${govk}K"
fi

if [ "$fire_ctx" -eq 1 ]; then
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
  ctx_msg="${head} ${order}${extra}"
else
  # Solo disparó la cuota: la línea de contexto es informativa (no es la preocupación), sin orden ni andamio.
  ctx_msg="📊 Contexto ~${pctw}% de ${den} (${ctxk}K)."
fi

# Línea de CUOTA (si hay snapshot). Cuando la cuota disparó, añade el nudge de acción (sin consejo inventado:
# el freno duro al delegar lo sigue poniendo limite-gasto).
quota_msg=""
if [ -n "$quota_line" ]; then
  quota_msg="📈 Cuota —${quota_line}"
  [ "$fire_quota" -eq 1 ] && quota_msg="$quota_msg Pacea el ritmo si vas a seguir; el freno al delegar lo pone limite-gasto."
fi

# Compone las líneas que haya (al menos una, garantizado por el exit de arriba).
if [ -n "$quota_msg" ]; then
  msg=$(printf '%s\n%s' "$ctx_msg" "$quota_msg")
else
  msg="$ctx_msg"
fi
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
