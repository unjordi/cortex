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
#   que en exportar-sesion-master.sh). Escritura ATÓMICA (tmp+rename dentro del .js): el andamio nunca
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
  local sid="${1:-}" tpath="${2:-}" root="${3:-}" mem="${4:-}" selfdir="${5:-}" invoker="${6:-?}"

  # sid saneado + ruta del log (vive en $mem; se computa cuanto antes para registrar incluso los skips).
  local sidsan log=""
  sidsan="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')"; [ -n "$sidsan" ] || sidsan="nosid"
  [ -n "$mem" ] && [ -d "$mem" ] && log="$mem/.checkpoint-mecanico.log"
  # Una LÍNEA por evento (fecha · invocador · sid · detalle), para saber si el disparo corrió o se omitió y por
  # qué. Rotación: si pasa de 400 líneas, deja las últimas 200 (que no crezca sin fin). Best-effort (fail-safe).
  _ckpt_log() {
    [ -n "$log" ] || return 0
    if [ -f "$log" ]; then   # rotación solo si ya existe (evita el error de `< $log` sobre un log ausente)
      local n; n=$(wc -l < "$log" 2>/dev/null || echo 0); case "$n" in ''|*[!0-9]*) n=0 ;; esac
      [ "$n" -gt 400 ] && { tail -n 200 "$log" > "$log.tmp" 2>/dev/null && mv -f "$log.tmp" "$log" 2>/dev/null; }
    fi
    printf '%s · %s · sid=%s · %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '?')" "$invoker" "$sidsan" "$1" >> "$log" 2>/dev/null || true
  }

  [ "${_CORTEX_CKPT_MECANICO_RUNNING:-0}" = "1" ] && { _ckpt_log "omitido: recursion"; return 0; }
  command -v node >/dev/null 2>&1 || { _ckpt_log "omitido: sin node"; return 0; }
  command -v jq   >/dev/null 2>&1 || { _ckpt_log "omitido: sin jq"; return 0; }
  [ -n "$tpath" ] && [ -f "$tpath" ] || { _ckpt_log "omitido: sin transcript"; return 0; }
  [ -n "$mem" ]   && [ -d "$mem" ]   || return 0   # sin $mem no hay dónde loguear ni incumbe (repo sin memoria)

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
  [ -n "$exp" ] || { _ckpt_log "omitido: sin extractor"; return 0; }

  # ── lock por-sid (evita solapar dos volcados de la misma sesión; huérfano >10 min se recicla) ──
  local lock="$mem/.checkpoint-mecanico-$sidsan.lock"
  if [ -f "$lock" ]; then
    local lnow lmt
    lnow=$(date +%s 2>/dev/null || echo 0)
    lmt=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo 0)
    case "$lnow" in ''|*[!0-9]*) lnow=0 ;; esac
    case "$lmt"  in ''|*[!0-9]*) lmt=0 ;; esac
    [ "$lmt" -gt 0 ] && [ $(( lnow - lmt )) -lt 600 ] && { _ckpt_log "omitido: lock"; return 0; }
  fi
  : > "$lock" 2>/dev/null || true

  # node corre en BACKGROUND (su exit se perdería) → el subshell registra `exit=<n> andamio=<mtime>` al terminar.
  local out="$mem/hilo-mental-actual.andamio.md"
  _ckpt_log "lanzado"
  nohup env _CORTEX_CKPT_MECANICO_RUNNING=1 bash -c '
    EXP="$1"; T="$2"; OUT="$3"; ROOT="$4"; lock="$5"; LOG="$6"; INV="$7"; SID="$8"
    node "$EXP" "$T" --out "$OUT" --repo-root "$ROOT" >/dev/null 2>>"$LOG"; rc=$?
    mt=$(stat -c %Y "$OUT" 2>/dev/null || stat -f %m "$OUT" 2>/dev/null || echo "?")
    printf "%s · %s · sid=%s · exit=%s andamio=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "?")" "$INV" "$SID" "$rc" "$mt" >> "$LOG" 2>/dev/null
    rm -f "$lock" 2>/dev/null
  ' _ "$exp" "$tpath" "$out" "$root" "$lock" "$log" "$invoker" "$sidsan" >/dev/null 2>&1 &

  return 0
}
