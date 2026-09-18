#!/usr/bin/env bash
# recordar-cosechar.sh — Stop hook (tier REPO). ESPEJO automático, silencioso e idempotente del TaskList
# vivo → el bloque `<!-- espejo-tasklist -->` DENTRO de .claude/memory/estado-proyecto.md, para que el
# backlog durable (que viaja por git y ven los otros claudios/colegas) refleje la vista de tareas sin
# fricción del modelo. Determinista, SIN LLM. Solo toca ESE bloque; jamás la prosa curada. Solo si
# estado-proyecto.md YA existe (no lo crea). NUNCA bloquea.
#
# La maquinaria vive en la LIB `sincronizar-tasklist.sh` (UN dueño; el skill to-do la EJECUTA para el
# sentido inverso — bloque → HUD). Este hook la SOURCEA y dispara el sentido Stop (json → bloque).
#
# Rediseño 2026-09-18 (sync bidireccional): antes el espejo escribía RUIDO — con el session_id ROTADO (que
# el harness cambia sin aviso al arrancar/compactar) el sid del payload apuntaba a una carpeta vacía y el
# hook PISABA el bloque con "_(sin pendientes)_ · +0", borrando el último espejo bueno. Arreglos en la lib:
# (1) selección de carpeta ROBUSTA a la rotación (payload sid → si vacío, la más reciente en ventana);
# (2) ANTI-CLOBBER (nunca pisa un bloque no-vacío con uno vacío). Además vuelve el NUDGE, ahora ATADO al
# sync REAL: solo avisa cuando espejó ≥1 pendiente vivo Y el bloque cambió — no es un recordatorio
# decorativo en cada Stop (esa mitad advisory se había medido ignorada y retirado; regresa anclada al hecho).
#
# Fail-open SIEMPRE: no-git / sin jq / cualquier error → silencio, exit 0. NUNCA bloquea.
# Escape: CLAUDE_SKIP_RECORDAR_COSECHAR=1.
set -u

payload=$(cat 2>/dev/null || true)   # capturar stdin (contrato Stop trae session_id/transcript_path/stop_hook_active)

[ "${CLAUDE_SKIP_RECORDAR_COSECHAR:-0}" = 1 ] && exit 0

# Anti-loop: si este Stop lo disparó otro hook Stop, no re-entrar (el nudge no debe re-avisar en cadena).
if command -v jq >/dev/null 2>&1; then
  [ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[ -n "$ROOT" ] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Solo aplica a repos con el sistema de memoria (donde vive el backlog).
[ -d "$ROOT/.claude/memory" ] || exit 0

# ── Cargar la lib (blindado: un error de sintaxis en la lib NO tumba el hook) ────────────────────────────
_STL_LIB="$(dirname "$0")/sincronizar-tasklist.sh"
if [ -f "$_STL_LIB" ] && bash -n "$_STL_LIB" 2>/dev/null; then
  # shellcheck source=sincronizar-tasklist.sh
  . "$_STL_LIB"
else
  exit 0   # sin la lib no hay maquinaria; fail-open silencioso (nunca bloquea el Stop).
fi

# ── ESPEJO — json → bloque durable. Devuelve el nº de pendientes espejados. ──────────────────────────────
n_espejados=$(espejar_tasklist "$payload" "$ROOT" 2>/dev/null || echo 0)
case "$n_espejados" in ''|*[!0-9]*) n_espejados=0 ;; esac

# ── NUDGE útil, ATADO al sync real: solo si de verdad espejó pendientes vivos este Stop ──────────────────
if [ "$n_espejados" -gt 0 ] && command -v jq >/dev/null 2>&1; then
  msg="🔄 Espejé $n_espejados pendiente(s) del TaskList al bloque de estado-proyecto.md. Recuerda: la CURACIÓN (decisiones tomadas, prioridades, contexto) va AFUERA del bloque espejo — ¿el backlog durable y la bitácora reflejan lo que decidiste/avanzaste este turno?"
  jq -n --arg m "$msg" '{systemMessage:$m}' 2>/dev/null || true
fi
exit 0
