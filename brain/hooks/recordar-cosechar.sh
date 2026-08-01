#!/usr/bin/env bash
# recordar-cosechar.sh — Stop hook (tier REPO). Nudge GENTIL y NO bloqueante de "trabajaste y no
# dejaste memoria durable". Cubre DOS señales con UN SOLO aviso al día (no duplica el nagging):
#   (1) COSECHA: hubo trabajo sustantivo pero .claude/memory/aprendizajes.md NO fue tocado → recuerda
#       correr `/cosechar-sesion` antes de cerrar (si aprendiste algo durable).
#   (2) BACKLOG DURABLE: hubo trabajo sustantivo pero el backlog vivo NO fue tocado —
#       .claude/memory/estado-proyecto.md NI .claude/memory/bitacora.md → recuerda reflejar AHORA lo
#       que avanzaste/decidiste/parqueaste (el chat no es la fuente de verdad; el backlog sí).
# El mensaje es CONDICIONAL: menciona AMBAS si faltan ambas, o solo la que falte. NUNCA bloquea.
#
# Por qué EXISTE (pedido explícito de unjordi): "SIN MEMORIA DURABLE NO SOMOS NADA". La cosecha LOCAL
# alimenta el inbox de aprendizajes del equipo; el backlog durable (estado-proyecto.md / bitacora.md) es
# la fuente de verdad de "qué sigue / qué pasó". Ambos se descuidan sin un empujón al cerrar el día.
# "Norma sin mecanismo = buen deseo" → este hook es el mecanismo. Es la mitad "recuérdame" del par con
# la skill `cosechar-sesion` (la mitad "hazlo") y con las normas de backlog/decisiones-a-disco.
#
# HEURÍSTICO de "hubo trabajo sustantivo" (simple y robusto, elegido a propósito):
#   trabajo = (A) hubo commits en las últimas RECORDAR_COSECHAR_HORAS_TRABAJO (default 6), O
#             (B) el working tree tiene cambios en archivos de CÓDIGO (*.cs/*.razor/*.ts/*.js/*.sh/
#                 *.py/*.sql/*.css/*.html). Cualquiera de las dos basta.
#   "tocado" (para CUALQUIER archivo durable) = cambió en git en esa ventana O está modificado sin
#             commitear. aprendizajes.md tocado → cosecha OK; estado-proyecto.md O bitacora.md tocado →
#             backlog OK.
#   Si hubo trabajo Y falta al menos uno → avisa lo que falte (1×/día/repo). Si no hubo trabajo, o ambos
#   al día → silencio.
# Es un PROXY: no distingue "trabajo que dejó memoria durable" de "trabajo trivial" — por eso el aviso es
# suave y condicional ("...si aprendiste/avanzaste algo"), y el throttle fuerte evita que sea naggy.
#
# Throttle FUERTE: máx 1 aviso por DÍA por repo (stamp por-repo en ~/.claude/memory/.recordar-cosechar/),
# compartido por AMBAS señales → un solo nudge al día que cubre lo que falte.
# Escape: CLAUDE_SKIP_RECORDAR_COSECHAR=1.
# Fail-open SIEMPRE: no-git / sin jq / cualquier error → silencio, exit 0. NUNCA bloquea.
set -u

cat >/dev/null 2>&1 || true   # drenar stdin (contrato Stop)

[ "${CLAUDE_SKIP_RECORDAR_COSECHAR:-0}" = 1 ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[ -n "$ROOT" ] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Solo aplica a repos con el sistema de memoria (donde vive el inbox de aprendizajes + el backlog).
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0
LOG_REL=".claude/memory/aprendizajes.md"
ESTADO_REL=".claude/memory/estado-proyecto.md"
BITACORA_REL=".claude/memory/bitacora.md"

# tocado <ruta-rel> → 0 (true) si un commit reciente la tocó O está modificada sin commitear.
tocado() {
  local rel="$1"
  git -C "$ROOT" log --oneline --since="$horas hours ago" -- "$rel" 2>/dev/null | grep -q . && return 0
  git -C "$ROOT" status --porcelain -- "$rel" 2>/dev/null | grep -q . && return 0
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
horas="${RECORDAR_COSECHAR_HORAS_TRABAJO:-6}"; case "$horas" in ''|*[!0-9]*) horas=6;; esac
trabajo=0
# (A) commits recientes
n_commits=$(git -C "$ROOT" log --oneline --since="$horas hours ago" 2>/dev/null | grep -c . || echo 0)
case "$n_commits" in ''|*[!0-9]*) n_commits=0;; esac
[ "$n_commits" -gt 0 ] && trabajo=1
# (B) cambios de código sin commitear en el working tree
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

# ── ¿Se tocó el BACKLOG durable (estado-proyecto.md O bitacora.md)? ──
backlog_ok=0
tocado "$ESTADO_REL" && backlog_ok=1
[ "$backlog_ok" -eq 0 ] && tocado "$BITACORA_REL" && backlog_ok=1

# Ambas señales al día → silencio.
[ "$cosechado" -eq 1 ] && [ "$backlog_ok" -eq 1 ] && exit 0

# ── Avisar (gentil, no bloqueante) y marcar el throttle del día ──
printf '%s' "$hoy" > "$stamp" 2>/dev/null || true

msg_cosecha="🌾 Parece que trabajaste en este repo y no cosechaste aprendizajes hoy. Si aprendiste algo DURABLE (feedback del usuario, una lección de proceso, un gotcha no-obvio), corre \`/cosechar-sesion\` antes de cerrar para appendearlo al inbox del equipo (\`$LOG_REL\`). Si no hubo nada durable, ignórame."
msg_backlog="📋 Trabajaste y no actualizaste tu backlog durable (\`estado-proyecto.md\` / \`bitacora.md\`). Si avanzaste/decidiste/parqueaste algo, refléjalo AHORA (el chat no es la fuente de verdad; el backlog sí). Si no cambió nada del estado, ignórame."

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
