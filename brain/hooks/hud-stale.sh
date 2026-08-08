#!/usr/bin/env bash
# hud-stale.sh — SessionStart + PostToolUse/Bash hook (tier BOTH). Avisa —NO bloquea— cuando la lista
# de TODOs de la terminal (el "HUD": el árbol de checkboxes de TodoWrite/TaskList que unjordi ama) quedó
# STALE porque el CONTEXTO DE TAREA rotó: cambiaste de RAMA git o de PROYECTO/cwd, y el HUD sigue mostrando
# los pendientes de la tarea ANTERIOR (la queja literal: "me muestra tareas de otro proyecto/sesión").
#
# POR QUÉ EXISTE (unjordi, 2026-08-07, decisión textual): "NO QUIERO DRIFT NUNCA Y MENOS EN MI LISTA DE
# PENDIENTES" → un mecanismo que DETECTA/FLAGGEA el staleness de la lista, no el enfoque pasivo de
# solo-framing. El HUD es SCRATCH de sesión; el backlog DURABLE es estado-proyecto.md (de ESE repo/rama).
# El skill /to-do DERIVA el HUD del durable, pero NADA avisaba cuando lo mostrado dejó de coincidir con la
# realidad tras rotar el working tree. Este hook es ese aviso. Diseño completo:
# docs/propuestas/mecanismo-todos-consistente.md (Opción D, pieza #3).
#
# QUÉ DETECTA — solo SEÑALES OBJETIVAS, nunca el CONTENIDO del HUD (un hook no puede leer de forma robusta
# la task-list del harness para juzgar "¿está stale respecto a lo que haces?" → eso es semántico y sería
# una máquina de falsos positivos). El detector compara el CONTEXTO (repo root + rama git) de AHORA contra
# el ÚLTIMO observado EN ESTA MISMA SESIÓN. Si difiere → el HUD probablemente es de la tarea anterior.
# El cambio de rama/cwd es el TRIGGER, no el VEREDICTO: el mensaje es CONDICIONAL ("si ya no aplica,
# resetéalo"), nunca ordena borrar.
#
# PRECISIÓN (requisito de primera clase — un HUD que avisa en falso mata la confianza, misma lección que
# los otros guards). Cómo evita falsos positivos, por capas:
#   1. TRIGGER OBJETIVO: solo rama/cwd; jamás juzga el contenido del HUD → el FP semántico es IMPOSIBLE por
#      construcción.
#   2. STAMP POR-SESIÓN (key = session_id del payload): sesiones/worktrees CONCURRENTES en repos o ramas
#      distintos NO se pisan. Un stamp GLOBAL único haría thrash entre sesiones paralelas (unjordi corre
#      muchas a la vez) → falso "cambiaste de proyecto" en cada tool. El stamp per-sesión lo elimina.
#   3. FIRST-SIGHT SILENCIOSO: sin stamp previo para esta sesión → registra el baseline y CALLA. Nunca avisa
#      sobre un contexto que jamás observó; solo ante un CAMBIO observado dentro de la MISMA sesión.
#   4. DEBOUNCE POR TRANSICIÓN: tras avisar, actualiza el stamp a lo actual → no re-avisa la misma
#      transición. Una rama estable (mismos root+rama entre eventos) no dispara nunca.
#   5. GATE DE SISTEMA: solo procede si el repo ACTUAL tiene backlog durable (estado-proyecto.md / variantes).
#      Silencio total en repos/dirs que NO usan el sistema de memoria (mismo principio que todo hook del
#      cerebro). Y la acción sugerida ("re-siembra del estado-proyecto.md de ESTA rama") SOLO tiene sentido
#      si ese archivo existe. Tradeoff CONSERVADOR conocido: no cubre la staleness al SALIR hacia un dir sin
#      backlog (favorece precisión sobre recall) — decisión abierta documentada en la propuesta.
#   6. FAIL-OPEN: sin jq / sin git / sin session_id / cualquier error → exit 0 silencioso.
#
# ADVISORY por diseño: inyecta additionalContext PASIVO (el patrón fiable ya usado por rehidratar-hilo y
# aviso-contexto), NUNCA bloquea. Reusa la MISMA noción "contexto registrado vs actual" que
# rehidratar-hilo.sh aplica al HILO (rama del hilo vs rama actual), trasladada al HUD.
#
# Genérico y stack-agnóstico. Tier BOTH: se instala GLOBAL (install-brain.sh) Y viaja POR-REPO a los repos
# COMPARTIDOS (sincronizar-cerebro.sh) como CORREO, para el colega que clona SIN el brain global. Pareja
# conceptual del skill /to-do (que SIEMBRA el HUD del durable) y de rehidratar-hilo (que relee el HILO).
# Escape: CLAUDE_SKIP_HUD_STALE=1.
set -u

# dedupe doble-cableado: si soy la copia del REPO y la copia GLOBAL existe, cedo (la global maneja esta
# invocación) → evita el aviso DUPLICADO; en un clon SIN bootstrap (sin copia global) la del repo sí corre.
# Necesario ahora que hud-stale es tier `both` (viaja per-repo Y global). NO-debilitante: sigue avisando 1×.
case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac

[ "${CLAUDE_SKIP_HUD_STALE:-0}" = 1 ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0        # sin jq no podemos parsear el payload → fail-open

input=$(cat 2>/dev/null || true)               # drenar+capturar stdin (SessionStart {source,session_id,…} · PostToolUse {tool_name,…})

# ── Gate de EVENTO: si nos disparó un PostToolUse, solo seguimos si la tool fue Bash (donde vive un
#    `git checkout`/`cd` que rota el contexto). Cualquier otra tool → silencio inmediato. En SessionStart
#    no hay .tool_name → seguimos (source=startup/resume/compact/clear/fork). ────────────────────────────
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ -n "$tool_name" ] && [ "$tool_name" != "Bash" ] && exit 0
event_name="SessionStart"; [ "$tool_name" = "Bash" ] && event_name="PostToolUse"

# ── session_id: la CLAVE del stamp per-sesión (la pieza que evita el thrash entre sesiones paralelas).
#    Sin él no podemos aislar por sesión → fail-open (mejor callar que arriesgar un FP cross-sesión). ────
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
sid=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')   # sanitiza a nombre de archivo seguro

# ── CONTEXTO ACTUAL: repo root + rama git. ──────────────────────────────────────────────────────────────
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[ -n "$ROOT" ] || exit 0
MEM="$ROOT/.claude/memory"

# ── GATE DE SISTEMA: el repo ACTUAL debe tener backlog durable (el HUD se DERIVA de él; re-sembrarlo solo
#    tiene sentido si existe). Silencio en repos/dirs que no usan el sistema. ─────────────────────────────
has_backlog=0
for f in estado-proyecto estado-y-pendientes backlog-desarrollo estado; do
  [ -f "$MEM/$f.md" ] && { has_backlog=1; break; }
done
[ "$has_backlog" = 1 ] || exit 0

cur_branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
cur_ctx="${ROOT}|${cur_branch}"

# ── STAMP POR-SESIÓN: última (root|rama) observada en ESTA sesión. ──────────────────────────────────────
STAMPDIR="$HOME/.claude/memory/.hud-stale"
mkdir -p "$STAMPDIR" 2>/dev/null || exit 0     # sin poder crear el stamp → fail-open (no arriesgar FP sin memoria)
STAMP="$STAMPDIR/$sid"

# Poda best-effort de stamps viejos (>14 días) para no acumular un archivo por sesión histórica.
find "$STAMPDIR" -type f -mtime +14 -delete 2>/dev/null || true

prev_ctx=""
[ -f "$STAMP" ] && prev_ctx=$(cat "$STAMP" 2>/dev/null || echo "")

# FIRST-SIGHT o SIN-CAMBIO → registra baseline y CALLA (jamás avisa sin un cambio observado en la sesión).
if [ -z "$prev_ctx" ] || [ "$prev_ctx" = "$cur_ctx" ]; then
  printf '%s' "$cur_ctx" > "$STAMP" 2>/dev/null || true
  exit 0
fi

# ── CAMBIÓ el contexto dentro de la misma sesión → el HUD puede ser de la tarea anterior. AVISA (pasivo) y
#    actualiza el stamp (debounce: no re-avisa esta misma transición). ────────────────────────────────────
printf '%s' "$cur_ctx" > "$STAMP" 2>/dev/null || true

prev_branch="${prev_ctx##*|}"; prev_root="${prev_ctx%|*}"
if [ "$prev_root" != "$ROOT" ]; then
  que="cambiaste de PROYECTO (de \`$(basename "$prev_root")\` a \`$(basename "$ROOT")\`)"
else
  que="cambiaste de RAMA (de \`${prev_branch:-?}\` a \`${cur_branch:-?}\`)"
fi

msg="🔀 HUD POSIBLEMENTE STALE — ${que} desde tu última acción en esta sesión. Tu lista de TODOs de la terminal (el HUD) puede seguir mostrando los pendientes de la tarea ANTERIOR. Si ya no aplican a lo que haces AHORA, RESETÉALA: re-siémbrala del backlog durable de ESTA rama/repo (estado-proyecto.md) con el skill /to-do, o límpiala. Es TU HUD de working-memory (tu tablero para no perderte), no un reporte para el usuario — un aviso que te salva de trabajar con una lista vieja, no una orden. (Detección OBJETIVA por cambio de rama/cwd; NO leí el contenido de tu lista.)"

jq -n --arg c "$msg" --arg e "$event_name" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
exit 0
