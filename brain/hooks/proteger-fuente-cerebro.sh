#!/usr/bin/env bash
# proteger-fuente-cerebro.sh — PreToolUse/{Edit,Write,MultiEdit}: AVISA (NO bloquea) cuando estás
# editando la copia INSTALADA de una skill/hook del cerebro (~/.claude/skills|hooks/) que TIENE una
# FUENTE correspondiente en el clon canónico (brain/skills|hooks/). Antídoto a un HUECO real (cazado
# por el db-master): una regla escrita directo en la copia INSTALADA es REGENERABLE — el próximo
# `install-brain` la SOBRESCRIBE con la fuente y la edita MUERE, sin dejar rastro. La fuente única es
# el clon canónico; la instalada es un DESPLIEGUE. `unificar-cerebro` cubre brain→repo (mini→develop),
# pero NO este sentido (instalada→fuente) — por eso este guard.
#
# Doc=realidad: la única copia que sobrevive un re-install es la del clon canónico
# (${CLAUDE_BRAIN_DIR:-$HOME/.cortex}/brain/…). Editar la instalada es editar un artefacto que
# se re-genera; el aviso redirige a la fuente y recuerda propagar (install-brain / sincronizar-cerebro).
#
# - Solo avisa si el file_path cae bajo $HOME/.claude/skills/ o $HOME/.claude/hooks/ Y existe la fuente
#   correspondiente (mismo relativo) en el clon canónico. Skill/hook PURAMENTE local (sin fuente) →
#   silencio (no es el error que vigilamos).
# - NUNCA bloquea (additionalContext). FAIL-OPEN: sin jq / sin file_path / cualquier error → exit 0.
# - Rápido (dispara en CADA Edit/Write/MultiEdit): un jq, un case de prefijo y un test -f.
# - Escape: env CLAUDE_SKIP_PROTEGER_FUENTE=1.
#
# Vive en brain/hooks/ (fuente); tier `global` (solo ~/.claude/hooks, lo instala el bootstrap) → sin
# cláusula de dedupe (no viaja por-repo, no hay doble cableado que deduplicar).

[ "${CLAUDE_SKIP_PROTEGER_FUENTE:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# El JSON del hook llega por stdin; sacamos el file_path (igual para Edit/Write/MultiEdit).
fp=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$fp" ] && exit 0

# ¿Cae bajo la copia INSTALADA (skills|hooks)? Deriva el relativo (incluye el subdir) → así el mismo
# relativo aplica a la FUENTE brain/<subdir>/…
case "$fp" in
  "$HOME/.claude/skills/"*) relsub="skills/${fp#"$HOME/.claude/skills/"}" ;;
  "$HOME/.claude/hooks/"*)  relsub="hooks/${fp#"$HOME/.claude/hooks/"}" ;;
  *) exit 0 ;;
esac

# resolve_brain_dir() vive en drift-cerebro-comun.sh (misma carpeta, fuente y una vez instalado) — mismo
# orden/fallback que los widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain. Si la lib no
# está (caso raro), cae al default histórico sin el fallback (fail-open, este guard nunca bloquea).
_selfdir="$(dirname "$0")"
if [ -f "$_selfdir/drift-cerebro-comun.sh" ]; then
  # shellcheck source=drift-cerebro-comun.sh
  . "$_selfdir/drift-cerebro-comun.sh"
  BRAIN_DIR="$(resolve_brain_dir)"
else
  BRAIN_DIR="${CLAUDE_BRAIN_DIR:-$HOME/.cortex}"
fi
src="$BRAIN_DIR/brain/$relsub"

# Sin fuente correspondiente → skill/hook puramente local → NO es este error → silencio.
[ -f "$src" ] || exit 0

MSG="AVISO (proteger-fuente-cerebro): estás editando la copia INSTALADA del cerebro ($fp). Es REGENERABLE: el próximo install-brain la SOBRESCRIBE con la fuente y tu edición se PIERDE sin rastro. Edita la FUENTE en: $src — y propaga con install-brain (global) o sincronizar-cerebro.sh (por-repo). Corre verificar-cerebro para ver TODO el drift instalada-vs-fuente. (Esto AVISA, no bloquea: si de verdad es un tweak local desechable, ignóralo o exporta CLAUDE_SKIP_PROTEGER_FUENTE=1.)"

jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
