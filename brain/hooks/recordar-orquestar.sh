#!/usr/bin/env bash
# recordar-orquestar.sh — PostToolUse (toda tool, tier GLOBAL). ADVISORY puro: recuerda considerar un
# FAN-OUT/delegación cuando Claude lleva RATO en "grind serial" (muchas mutaciones consecutivas) sin
# haber delegado NADA en la sesión. Mecanismo de la norma `orquestar-fanout` ("delega lo paralelizable
# y quédate disponible") — una norma de estilo SIN mecanismo no se cumple sola ("toda norma nace con su
# mecanismo"). Hermana del gate de costo `delegacion-gate` (que previene runaways): ese FRENA delegar de
# más; éste EMPUJA a delegar cuando conviene. Pieza del backlog #59 (B3 REC).
#
# NUNCA bloquea (additionalContext pasivo, jamás permissionDecision:deny) — es un recordatorio, no una
# orden. Si el trabajo es intrínsecamente SECUENCIAL, el modelo lo ignora (el texto lo dice explícito).
#
# ── SEÑAL (contador per-session_id, no transcript) ────────────────────────────────────────────────
# El stdin de PostToolUse YA trae `.tool_name` y `.tool_input` → no hace falta parsear el transcript.
# Por cada tool clasificamos:
#   • MUTACIÓN  (Edit/Write/MultiEdit/NotebookEdit, o un Bash que corre `git commit`) → count++
#   • RESET     (Agent/Task = una delegación) → count=0 (si YA delegaste, no te regaña por eso)
#   • NEUTRAL   (Read/Grep/Glob/Bash de lectura/etc.) → ni cuenta ni resetea → exit 0 silencioso
# El contador vive en $HOME/.claude/.recordar-orquestar/<session_id> ("<count> <last_advised>"):
# PER-SESSION (no global → sesiones paralelas no se pisan; el hilo de un subagente trae OTRO session_id,
# así que sus edits no contaminan el conteo del hilo principal — y como la delegación misma es un
# Agent/Task en el hilo principal, delegar RESETEA el contador aquí).
#
# ── PRECISIÓN (un aviso en falso mata la confianza, misma lección que los otros guards) ────────────
#   • Umbral N (RECORDAR_ORQUESTAR_N, def 10): 10 mutaciones SEGUIDAS sin UNA sola delegación. Bajo de 10
#     no dispara → un cambio corto y genuinamente serial (armar 3-4 archivos de un módulo, una edición
#     encadenada) nunca lo ve. Solo un grind SOSTENIDO sin delegar cruza el umbral.
#   • RESET al delegar: un Agent/Task pone count=0 → una sesión que delega seguido JAMÁS lo ve; solo la
#     que hace 10 mutaciones seguidas con CERO delegación en medio.
#   • Debounce: tras avisar en N, no re-avisa hasta 2N, 3N… (last_advised) → un aviso por cada bloque de N,
#     no un grito por cada edit tras cruzar el umbral.
#   • Serial LEGÍTIMO: no hay forma fiable de que un hook distinga "grind evitable" de "intrínsecamente
#     secuencial" (eso es criterio del modelo) → por eso es ADVISORY y el mensaje dice claro "si es serial
#     por naturaleza, IGNÓRALO". El costo de un falso positivo es UNA línea de contexto ignorable cada N,
#     no un bloqueo. Trade-off honesto: preferimos recordar de más (ignorable) que nunca (norma muerta).
#   • Fail-open: sin jq / sin session_id / sin dónde escribir el stamp → exit 0 silencioso.
#   • Escape: CLAUDE_SKIP_RECORDAR_ORQUESTAR=1 → exit 0.
#
# Tier GLOBAL (no `both`): es un nudge sobre el ESTILO de trabajo de Claude (cómo orquesta), agnóstico
# de repo/stack — no una política de git que un colega en un repo COMPARTIDO necesite heredar por git.
# Vive con la familia de delegación (delegacion-gate/registrar/reporte), toda global. Sin cláusula de
# dedupe (esa es solo para `both`).
set -u

[ -n "${CLAUDE_SKIP_RECORDAR_ORQUESTAR:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0            # sin jq no leemos el stdin → fail-open silencioso

input=$(cat 2>/dev/null || true)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ -n "$tool" ] || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0                            # sin session_id no hay contador per-sesión → fail-open
sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-'); [ -n "$sid" ] || exit 0

# Clasifica la tool. NEUTRAL sale ya (ni cuenta ni resetea → no toca disco).
kind=neutral
case "$tool" in
  Agent|Task)                        kind=reset ;;
  Edit|Write|MultiEdit|NotebookEdit) kind=mutacion ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    # `git commit` (incluye `&& git commit`, `git commit -m`); NO `git log --grep commit` ni menciones.
    printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)' && kind=mutacion ;;
esac
[ "$kind" = neutral ] && exit 0

BASE="${HOME:-}/.claude/.recordar-orquestar"
[ -n "${HOME:-}" ] || BASE="${TMPDIR:-/tmp}/.recordar-orquestar"
mkdir -p "$BASE" 2>/dev/null || exit 0             # sin dónde escribir el stamp → fail-open
F="$BASE/$sid"

count=0; last=0
if [ -f "$F" ]; then
  read -r count last _ < "$F" 2>/dev/null || true
  case "${count:-}" in ''|*[!0-9]*) count=0 ;; esac
  case "${last:-}"  in ''|*[!0-9]*) last=0  ;; esac
fi

# RESET: una delegación → contador a 0 (ya delegaste; no te regaño por eso). Silencio.
if [ "$kind" = reset ]; then
  printf '0 0\n' > "$F" 2>/dev/null || true
  exit 0
fi

# MUTACIÓN: incrementa y decide si avisar.
N="${RECORDAR_ORQUESTAR_N:-10}"; case "$N" in ''|*[!0-9]*) N=10 ;; esac; [ "$N" -ge 1 ] 2>/dev/null || N=10
count=$((count + 1))

# Debounce: avisa al llegar a N, y luego solo cada N más (2N, 3N…). last = último count avisado.
fire=0
if [ "$count" -ge "$N" ] && [ "$count" -ge "$((last + N))" ]; then
  fire=1; last="$count"
fi
printf '%s %s\n' "$count" "$last" > "$F" 2>/dev/null || true

[ "$fire" = 1 ] || exit 0

msg="🎼 Llevas ${count} cambios EN SERIE (edits/commits) sin delegar a NINGÚN agente en esta sesión. Si lo que queda tiene PIEZAS INDEPENDIENTES (varios módulos/archivos/ítems de backlog que no dependen entre sí), considera un FAN-OUT: delégalas a agentes en PARALELO (worktrees aislados) y quédate como ORQUESTADOR — revisando diffs, armando MRs, haciendo QA y disponible para el usuario (skill: orquestar-fanout). Si en cambio el trabajo es INTRÍNSECAMENTE SECUENCIAL (cada paso depende del anterior: una refactorización encadenada, depurar un bug, una migración paso-a-paso) IGNORA esto — es un recordatorio ADVISORY, no una orden. (Silenciar: CLAUDE_SKIP_RECORDAR_ORQUESTAR=1)"

jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
