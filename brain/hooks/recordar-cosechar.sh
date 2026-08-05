#!/usr/bin/env bash
# recordar-cosechar.sh — Stop hook (tier REPO). Hace DOS cosas al terminar un turno; NUNCA bloquea:
#   • ESPEJO (automático, silencioso, idempotente): vuelca los PENDIENTES del TaskList vivo de la sesión
#     a un bloque fenced `<!-- espejo-tasklist -->` DENTRO de .claude/memory/estado-proyecto.md, para que
#     el backlog durable (que viaja por git y ven los otros claudios/colegas) refleje la vista de tareas
#     sin fricción. Determinista (lee ~/.claude/tasks/<session-id>/*.json con jq → markdown); NO usa LLM.
#     Solo toca ESE bloque; jamás la prosa curada. Solo si estado-proyecto.md YA existe (no lo crea).
#   • NUDGE gentil (1×/día/repo) de "trabajaste y no dejaste memoria durable", con DOS señales:
#       (1) COSECHA: hubo trabajo sustantivo pero .claude/memory/aprendizajes.md NO fue tocado → recuerda
#           correr `/cosechar-sesion` antes de cerrar (si aprendiste algo durable).
#       (2) BACKLOG DURABLE: hubo trabajo sustantivo pero el backlog vivo NO fue tocado POR UN HUMANO —
#           estado-proyecto.md (fuera del bloque espejo) NI bitacora.md → recuerda reflejar AHORA lo que
#           avanzaste/decidiste/parqueaste (el chat no es la fuente de verdad; el backlog sí).
#     Mensaje CONDICIONAL: menciona AMBAS si faltan ambas, o solo la que falte. NUNCA bloquea.
#
# Por qué EXISTE (pedido explícito de unjordi): "SIN MEMORIA DURABLE NO SOMOS NADA". El espejo hace que los
# PENDIENTES estén siempre reflejados sin esfuerzo; el nudge cubre lo que sí necesita JUICIO humano (la
# prosa: decisiones con su porqué, contexto, bitácora). "Norma sin mecanismo = buen deseo" → este hook es
# el mecanismo. Es la mitad "recuérdame" del par con la skill `cosechar-sesion` (la mitad "hazlo").
#
# Clave de diseño (el espejo NO auto-suprime el nudge): como el espejo escribe estado-proyecto.md, un
# chequeo ingenuo "¿estado-proyecto.md modificado?" daría siempre true y mataría el nudge (2). Por eso el
# chequeo de backlog-humano IGNORA el bloque espejo: compara el contenido de estado-proyecto.md FUERA de
# los marcadores contra HEAD; solo cuenta como "tocado por humano" si cambió algo afuera del bloque (o si
# hubo un commit reciente que lo tocó). bitacora.md no tiene bloque → chequeo simple.
#
# HEURÍSTICO de "hubo trabajo sustantivo" (simple y robusto, elegido a propósito):
#   trabajo = (A) hubo commits en las últimas RECORDAR_COSECHAR_HORAS_TRABAJO (default 6), O
#             (B) el working tree tiene cambios en archivos de CÓDIGO (*.cs/*.razor/*.ts/*.js/*.sh/
#                 *.py/*.sql/*.css/*.html). Cualquiera de las dos basta.
# Es un PROXY: no distingue "trabajo que dejó memoria durable" de "trabajo trivial" — por eso el aviso es
# suave y condicional, y el throttle fuerte evita que sea naggy.
#
# Throttle FUERTE (solo el NUDGE, no el espejo): máx 1 aviso por DÍA por repo (stamp por-repo en
# ~/.claude/memory/.recordar-cosechar/), compartido por AMBAS señales → un solo nudge al día. El ESPEJO
# corre en CADA Stop (idempotente: solo escribe si el bloque cambió → sin churn cuando las tareas no mueven).
# Escape: CLAUDE_SKIP_RECORDAR_COSECHAR=1 (apaga TODO, espejo incluido).
# Fail-open SIEMPRE: no-git / sin jq / cualquier error → silencio, exit 0. NUNCA bloquea.
set -u

payload=$(cat 2>/dev/null || true)   # capturar stdin (contrato Stop trae session_id/transcript_path)

[ "${CLAUDE_SKIP_RECORDAR_COSECHAR:-0}" = 1 ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[ -n "$ROOT" ] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Solo aplica a repos con el sistema de memoria (donde vive el inbox de aprendizajes + el backlog).
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0
LOG_REL=".claude/memory/aprendizajes.md"
ESTADO_REL=".claude/memory/estado-proyecto.md"
BITACORA_REL=".claude/memory/bitacora.md"
ESPEJO_INI="<!-- espejo-tasklist:start -->"
ESPEJO_FIN="<!-- espejo-tasklist:end -->"

horas="${RECORDAR_COSECHAR_HORAS_TRABAJO:-6}"; case "$horas" in ''|*[!0-9]*) horas=6;; esac
TAB=$(printf '\t')

# ─────────────────────────────────────────────────────────────────────────────
# ESPEJO — automático, idempotente, silencioso. Corre en CADA Stop, antes del throttle/work-gates.
# ─────────────────────────────────────────────────────────────────────────────
espejar_tasklist() {
  command -v jq >/dev/null 2>&1 || return 0
  local estado="$ROOT/$ESTADO_REL"
  [ -f "$estado" ] || return 0   # NO crea el backlog; solo mantiene su bloque si ya existe.
  local sid; sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || return 0
  local tasksdir="$HOME/.claude/tasks/$sid"
  [ -d "$tasksdir" ] || return 0

  # Cuerpo del bloque desde los task JSON (en curso + pendientes, ordenados: in_progress antes de pending,
  # luego por id numérico). "in_progress" < "pending" alfabéticamente → el sort los ordena bien.
  local rows n_done body
  rows=$(for f in "$tasksdir"/*.json; do
           [ -f "$f" ] || continue
           jq -r 'select(.status=="in_progress" or .status=="pending")
                  | [.status, (.id|tonumber? // 0), (.subject // "")] | @tsv' "$f" 2>/dev/null
         done | sort -t"$TAB" -k1,1 -k2,2n)
  n_done=$(grep -l '"status": *"completed"' "$tasksdir"/*.json 2>/dev/null | grep -c . || echo 0)
  case "$n_done" in ''|*[!0-9]*) n_done=0;; esac

  body="## 🔄 Pendientes — espejo automático del TaskList (NO editar a mano)
> Lo mantiene el hook \`recordar-cosechar\` en cada Stop. Refleja el TaskList vivo de la sesión. La
> curación (decisiones, contexto, prioridades) va AFUERA de este bloque; aquí solo se espeja el estado."
  if [ -n "$rows" ]; then
    local st id subj icon
    while IFS="$TAB" read -r st id subj; do
      [ -n "$st" ] || continue
      case "$st" in in_progress) icon="🔸";; *) icon="▫️";; esac
      body="$body
- $icon **[$st]** #$id · $subj"
    done <<EOF2
$rows
EOF2
  else
    body="$body

_(sin pendientes ni tareas en curso)_"
  fi
  body="$body

_(+$n_done completadas · generado automáticamente)_"

  # Escritura idempotente: reemplazar el bloque (o crearlo al final) SOLO si cambió.
  local tmp; tmp=$(mktemp 2>/dev/null) || return 0
  if grep -qF "$ESPEJO_INI" "$estado" 2>/dev/null; then
    awk -v ini="$ESPEJO_INI" -v fin="$ESPEJO_FIN" -v body="$body" '
      $0==ini { print; print body; skip=1; next }
      $0==fin { skip=0; print; next }
      skip==1 { next }
      { print }
    ' "$estado" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  else
    { cat "$estado"; printf '\n%s\n%s\n%s\n' "$ESPEJO_INI" "$body" "$ESPEJO_FIN"; } > "$tmp" 2>/dev/null \
      || { rm -f "$tmp"; return 0; }
  fi
  if cmp -s "$tmp" "$estado" 2>/dev/null; then rm -f "$tmp"; else mv -f "$tmp" "$estado" 2>/dev/null || rm -f "$tmp"; fi
  return 0
}
espejar_tasklist   # fail-open interno; nunca tumba el hook

# ─────────────────────────────────────────────────────────────────────────────
# NUDGE — throttled 1×/día/repo.
# ─────────────────────────────────────────────────────────────────────────────
# tocado <ruta-rel> → 0 (true) si un commit reciente la tocó O está modificada sin commitear (simple).
tocado() {
  local rel="$1"
  git -C "$ROOT" log --oneline --since="$horas hours ago" -- "$rel" 2>/dev/null | grep -q . && return 0
  git -C "$ROOT" status --porcelain -- "$rel" 2>/dev/null | grep -q . && return 0
  return 1
}

# estado_tocado_por_humano → 0 (true) si estado-proyecto.md cambió AFUERA del bloque espejo (o commit
# reciente). Ignora los cambios que son SOLO del espejo → el espejo no auto-suprime el nudge (2).
estado_tocado_por_humano() {
  git -C "$ROOT" log --oneline --since="$horas hours ago" -- "$ESTADO_REL" 2>/dev/null | grep -q . && return 0
  local f="$ROOT/$ESTADO_REL" cur head_ver
  [ -f "$f" ] || return 1
  # Comparar el contenido FUERA del bloque, ignorando líneas en blanco (el espejo mete una línea vacía
  # separadora al crear el bloque → no debe contar como "cambio humano"; una línea vacía no es decisión).
  cur=$(sed "/$ESPEJO_INI/,/$ESPEJO_FIN/d" "$f" 2>/dev/null | grep -v '^[[:space:]]*$')
  head_ver=$(git -C "$ROOT" show "HEAD:$ESTADO_REL" 2>/dev/null | sed "/$ESPEJO_INI/,/$ESPEJO_FIN/d" | grep -v '^[[:space:]]*$')
  [ "$cur" != "$head_ver" ] && return 0
  return 1
}

# ── Throttle por repo: máx 1 aviso por día ──
stampdir="$HOME/.claude/memory/.recordar-cosechar"; mkdir -p "$stampdir" 2>/dev/null || true
slug=$(printf '%s' "$ROOT" | cksum 2>/dev/null | awk '{print $1}')
stamp="$stampdir/${slug:-0}"
hoy=$(date +%Y-%m-%d 2>/dev/null || echo "")
[ -n "$hoy" ] || exit 0
if [ -f "$stamp" ]; then
  last=$(cat "$stamp" 2>/dev/null || echo "")
  [ "$last" = "$hoy" ] && exit 0   # ya avisamos hoy en este repo
fi

# ── ¿Hubo trabajo sustantivo reciente? ──
trabajo=0
n_commits=$(git -C "$ROOT" log --oneline --since="$horas hours ago" 2>/dev/null | grep -c . || echo 0)
case "$n_commits" in ''|*[!0-9]*) n_commits=0;; esac
[ "$n_commits" -gt 0 ] && trabajo=1
if [ "$trabajo" -eq 0 ]; then
  if git -C "$ROOT" status --porcelain 2>/dev/null \
     | grep -qE '\.(cs|razor|ts|js|sh|py|sql|css|html)[[:space:]]*$'; then
    trabajo=1
  fi
fi
[ "$trabajo" -eq 0 ] && exit 0   # nada sustantivo → no molestamos

# ── ¿Se cosechó (se tocó aprendizajes.md)? ──
cosechado=0
tocado "$LOG_REL" && cosechado=1

# ── ¿Se tocó el BACKLOG durable POR UN HUMANO (estado-proyecto afuera del espejo, O bitacora)? ──
backlog_ok=0
estado_tocado_por_humano && backlog_ok=1
[ "$backlog_ok" -eq 0 ] && tocado "$BITACORA_REL" && backlog_ok=1

# Ambas señales al día → silencio.
[ "$cosechado" -eq 1 ] && [ "$backlog_ok" -eq 1 ] && exit 0

# ── Avisar (gentil, no bloqueante) y marcar el throttle del día ──
printf '%s' "$hoy" > "$stamp" 2>/dev/null || true

msg_cosecha="🌾 Parece que trabajaste en este repo y no cosechaste aprendizajes hoy. Si aprendiste algo DURABLE (feedback del usuario, una lección de proceso, un gotcha no-obvio), corre \`/cosechar-sesion\` antes de cerrar para appendearlo al inbox del equipo (\`$LOG_REL\`). Si no hubo nada durable, ignórame."
msg_backlog="📋 Trabajaste y no actualizaste tu backlog durable (\`estado-proyecto.md\` / \`bitacora.md\`). El espejo ya refleja tus PENDIENTES solo, pero las DECISIONES/contexto/porqués los pones tú: refléjalos AHORA (el chat no es la fuente de verdad; el backlog sí). Si no cambió nada del estado, ignórame."

ctx=""
[ "$cosechado" -eq 0 ] && ctx="$msg_cosecha"
if [ "$backlog_ok" -eq 0 ]; then
  if [ -n "$ctx" ]; then ctx="$ctx"$'\n\n'"$msg_backlog"; else ctx="$msg_backlog"; fi
fi
ctx="$ctx"$'\n\n'"(Aviso suave, 1×/día por repo.)"

if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$c}}'
else
  printf '%s\n' "$ctx"
fi
exit 0
