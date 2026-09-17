#!/usr/bin/env bash
# checkpoint-mecanico-comun.sh — LIB compartida (tier global). El LANZADOR del andamio MECÁNICO del
# checkpoint, factorizado del hook checkpoint-mecanico.sh (PreCompact) para que aviso-contexto.sh
# (PostToolUse) dispare el MISMO volcado al cruzar su umbral ALTO — UNA sola implementación, sin drift
# entre los dos invocadores. NO es un hook: ningún evento la cablea; los hooks la hacen `source`.
#
# disparar_checkpoint_mecanico <sid> <tpath> <root> <mem> [selfdir]
#   Lanza `bin/checkpoint-mecanico.js` DETACHED (nohup … &) para volcar el andamio MECÁNICO — el 🗂️ árbol
#   de archivos tocados, el RESUELTO HOY (mensajes de commit), las citas textuales del usuario y las
#   métricas de sesión — a <mem>/hilo-mental-actual.andamio.md, a CERO tokens de modelo. El juicio (en qué
#   estamos, decisión abierta, siguiente paso) lo sigue poniendo el modelo vivo en el checkpoint EN PROSA;
#   esto es la RED MECÁNICA que corre sola, no un reemplazo del checkpoint rico.
#
#   Detached (nohup … &) porque un transcript grande puede exceder el timeout del hook (mismo riesgo
#   medido en exportar-sesion-master.sh). Escritura ATÓMICA (tmp+rename dentro del .js): el andamio nunca
#   queda a medias si el auto-compact gana la carrera. El lock por-sid y el centinela anti-recursión son
#   IGUALES a los que usaba checkpoint-mecanico.sh, así los dos invocadores (PreCompact y el umbral de
#   aviso-contexto) COORDINAN: no se solapan ni corrompen el andamio, y no lo vuelcan dos veces seguidas.
#
#   CONTRATO: SILENCIOSO y FAIL-OPEN. Sin node/jq, sin extractor instalado, sin `.claude/memory`, sin
#   transcript, o con un lock vivo → no hace nada. Devuelve 0 SIEMPRE (nunca frena al invocador).
#
#   ANTI-RECURSIÓN: nunca invoca `claude` (no hay cadena de hooks que pueda re-disparar), pero se guarda
#   con el centinela de env `_CORTEX_CKPT_MECANICO_RUNNING` por si el evento del invocador llegara a
#   anidarse.

disparar_checkpoint_mecanico() {
  local sid="${1:-}" tpath="${2:-}" root="${3:-}" mem="${4:-}" selfdir="${5:-}"

  [ "${_CORTEX_CKPT_MECANICO_RUNNING:-0}" = "1" ] && return 0   # anti-recursión (centinela por env)
  command -v node >/dev/null 2>&1 || return 0
  command -v jq   >/dev/null 2>&1 || return 0
  [ -n "$tpath" ] && [ -f "$tpath" ] || return 0
  [ -n "$mem" ]   && [ -d "$mem" ]   || return 0   # repo sin sistema de memoria → no incumbe

  # ── localizar el extractor (2 rutas + resolve_brain_dir, mismo patrón que exportar-sesion-master.sh) ──
  local brain_dir exp c
  if [ -n "$selfdir" ] && [ -f "$selfdir/drift-cerebro-comun.sh" ]; then
    # shellcheck source=drift-cerebro-comun.sh
    . "$selfdir/drift-cerebro-comun.sh"
    brain_dir="$(resolve_brain_dir)"
  else
    brain_dir="${CLAUDE_BRAIN_DIR:-$HOME/.cortex}"
  fi
  exp=""
  for c in "$HOME/.local/bin/checkpoint-mecanico.js" "$brain_dir/bin/checkpoint-mecanico.js"; do
    [ -f "$c" ] && exp="$c" && break
  done
  [ -n "$exp" ] || return 0

  # ── lock por-sid (evita solapar dos volcados de la misma sesión; huérfano >10 min se recicla) ──
  local sidsan; sidsan="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')"
  [ -n "$sidsan" ] || sidsan="nosid"
  local lock="$mem/.checkpoint-mecanico-$sidsan.lock"
  if [ -f "$lock" ]; then
    local lnow lmt
    lnow=$(date +%s 2>/dev/null || echo 0)
    lmt=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo 0)
    case "$lnow" in ''|*[!0-9]*) lnow=0 ;; esac
    case "$lmt"  in ''|*[!0-9]*) lmt=0 ;; esac
    [ "$lmt" -gt 0 ] && [ $(( lnow - lmt )) -lt 600 ] && return 0
  fi
  : > "$lock" 2>/dev/null || true

  local out="$mem/hilo-mental-actual.andamio.md"
  local log="$mem/.checkpoint-mecanico.log"
  nohup env _CORTEX_CKPT_MECANICO_RUNNING=1 bash -c '
    EXP="$1"; T="$2"; OUT="$3"; ROOT="$4"; lock="$5"; LOG="$6"
    node "$EXP" "$T" --out "$OUT" --repo-root "$ROOT" >/dev/null 2>>"$LOG"
    rm -f "$lock" 2>/dev/null
  ' _ "$exp" "$tpath" "$out" "$root" "$lock" "$log" >/dev/null 2>&1 &

  return 0
}
