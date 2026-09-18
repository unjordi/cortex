#!/usr/bin/env bash
# recordar-cosechar.sh — Stop hook (tier REPO). ESPEJO automático, silencioso e idempotente: vuelca los
# PENDIENTES del TaskList vivo de la sesión a un bloque fenced `<!-- espejo-tasklist -->` DENTRO de
# .claude/memory/estado-proyecto.md, para que el backlog durable (que viaja por git y ven los otros
# claudios/colegas) refleje la vista de tareas sin fricción. Determinista (lee
# ~/.claude/tasks/<session-id>/*.json con jq → markdown); NO usa LLM. Solo toca ESE bloque; jamás la
# prosa curada. Solo si estado-proyecto.md YA existe (no lo crea). NUNCA bloquea.
#
# Overhaul hooks 2026-09-18: este hook hacía DOS cosas — el ESPEJO (mecanismo real, mutación) y un
# NUDGE de "trabajaste y no dejaste memoria durable" (puramente advisory, medido: ignorado). El NUDGE
# se RETIRÓ (subió a norma — brain/norms/global-claude-md.md § "Ningún hallazgo tuyo se queda solo
# narrado" / "Ninguna DECISIÓN se queda solo en el chat"): CERO-PÉRDIDA de la regla, pero deja de ser un
# hook — es disciplina de cierre de turno, igual que cosechar (skill cosechar-sesion / cerrar-slice §5).
# El ESPEJO se CONSERVA aquí porque no es "solo un recordatorio": es un mecanismo que MUTA
# estado-proyecto.md — apagarlo perdía una función real, no una norma.
#
# Fail-open SIEMPRE: no-git / sin jq / cualquier error → silencio, exit 0. NUNCA bloquea.
# Escape: CLAUDE_SKIP_RECORDAR_COSECHAR=1.
set -u

payload=$(cat 2>/dev/null || true)   # capturar stdin (contrato Stop trae session_id/transcript_path)

[ "${CLAUDE_SKIP_RECORDAR_COSECHAR:-0}" = 1 ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[ -n "$ROOT" ] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Solo aplica a repos con el sistema de memoria (donde vive el backlog).
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0
ESTADO_REL=".claude/memory/estado-proyecto.md"
ESPEJO_INI="<!-- espejo-tasklist:start -->"
ESPEJO_FIN="<!-- espejo-tasklist:end -->"
TAB=$(printf '\t')

# ─────────────────────────────────────────────────────────────────────────────
# ESPEJO — automático, idempotente, silencioso. Corre en CADA Stop.
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
exit 0
