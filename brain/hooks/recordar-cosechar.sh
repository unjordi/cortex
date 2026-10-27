#!/usr/bin/env bash
# recordar-cosechar.sh — Stop hook (tier BOTH). ESPEJO automático, silencioso e idempotente del TaskList
# vivo → el bloque `<!-- espejo-tasklist -->` DENTRO de .claude/memory/estado-proyecto.md, para que el
# backlog durable (que viaja por git y ven los otros claudios/colegas) refleje la vista de tareas sin
# fricción del modelo. Determinista, SIN LLM. Solo toca ESE bloque; jamás la prosa curada. Solo si
# estado-proyecto.md YA existe (no lo crea). NUNCA bloquea.
#
# La maquinaria vive en la LIB `sincronizar-tasklist.sh` (UN dueño; el skill to-do la EJECUTA para el
# sentido inverso — bloque → HUD). Este hook la SOURCEA y dispara el sentido Stop (json → bloque).
#
# Sync bidireccional. Con el session_id ROTADO (el harness lo cambia sin aviso al arrancar/compactar) el sid
# del payload puede apuntar a una carpeta vacía; la lib lo cubre con:
# (1) selección de carpeta ROBUSTA a la rotación (payload sid → si vacío, la más reciente en ventana);
# (2) ANTI-CLOBBER (nunca pisa un bloque no-vacío con uno vacío). Además el NUDGE cierra el
# LAZO del HUD: el harness NO refresca el HUD en pantalla desde disco (tiene la lista en memoria) → un hook
# NO puede sembrar el HUD, SOLO el modelo con las tools de to-do. Así que el nudge AVISA al modelo que
# actualizó el bloque durable y le sugiere re-sincronizar su task-list. Non-blocking (systemMessage) y solo
# cuando espejó ≥1 pendiente vivo Y el bloque cambió — no en cada Stop (propósito: cerrar el lazo json→durable→HUD).
#
# Fail-open SIEMPRE: no-git / sin jq / cualquier error → silencio, exit 0. NUNCA bloquea.
# Escape: CLAUDE_SKIP_RECORDAR_COSECHAR=1.
set -u

# dedupe (tier both): si soy la copia del REPO y la copia GLOBAL existe, cedo — evita doble disparo
# cuando el repo está brained Y hay bootstrap global. En un clon SIN bootstrap, la copia del repo corre.
_cfgh="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"; case "$0" in "$_cfgh/"*) : ;; *) [ -f "$_cfgh/$(basename "$0")" ] && exit 0 ;; esac

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

# ── Cargar la lib (blindado: un error de sintaxis en la lib NO tumba el hook) ────────────────────── ──
_STL_LIB="$(dirname "$0")/sincronizar-tasklist.sh"
if [ -f "$_STL_LIB" ] && bash -n "$_STL_LIB" 2>/dev/null; then
  # shellcheck source=sincronizar-tasklist.sh
  . "$_STL_LIB"
else
  exit 0   # sin la lib no hay maquinaria; fail-open silencioso (nunca bloquea el Stop).
fi

# ── ESPEJO — json → bloque durable. Devuelve el nº de pendientes espejados. ──────────────────────── ──
n_espejados=$(espejar_tasklist "$payload" "$ROOT" 2>/dev/null || echo 0)
case "$n_espejados" in ''|*[!0-9]*) n_espejados=0 ;; esac

# Sin aviso: el Stop copia el HUD vivo a la durable, así que el HUD ya está al día. La dirección inversa
# (durable → HUD) la hace el skill `to-do` en los bordes de la sesión.
exit 0
