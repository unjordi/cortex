#!/usr/bin/env bash
# proteger-fuente-cerebro.sh — PreToolUse/{Edit,Write,MultiEdit}: AVISA (NO bloquea) cuando estás
# editando una copia REGENERABLE del cerebro, en cualquiera de sus DOS formas:
#   (A) la copia INSTALADA global (~/.claude/skills|hooks/) que TIENE una FUENTE correspondiente en el
#       clon canónico (brain/skills|hooks/) → la SOBRESCRIBE el próximo `install-brain`.
#   (B) el CLON INFRA oculto (~/.cortex/brain/… o ~/.claude-brain/brain/…) — el clon que TODAS las
#       máquinas tienen y que el updater del widget FUERZA-ALINEA a origin/main (git checkout -B main
#       origin/main) → tu edición en sitio MUERE en el próximo update del widget.
# Antídoto a un HUECO real (cazado por el db-master; el caso (B) lo destapó axon-master editando skills
# EN SITIO en ~/.cortex). En ambos casos la copia es un DESPLIEGUE, no la fuente: la única que sobrevive
# es el clon de DESARROLLO (p.ej. ~/code/cortex), que se propaga por git. `canonizar-cerebro` (modo
# reconciliar) cubre brain→repo (mini→develop), pero NO instalada/infra→fuente — por eso este guard.
#
# - (A) avisa sólo si el file_path cae bajo ~/.claude/skills|hooks/ Y existe la fuente correspondiente
#   en el clon canónico. Skill/hook PURAMENTE local (sin fuente) → silencio.
# - (B) avisa si el file_path cae bajo ~/.cortex/brain/ o ~/.claude-brain/brain/ (rutas OCULTAS
#   canónicas del clon infra). Usa esas rutas fijas, NO $CLAUDE_BRAIN_DIR resuelto: si éste apunta a un
#   clon de DESARROLLO (~/code/cortex), ahí SÍ es fuente editable → NO avisa (anti-falso-positivo).
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

# ¿Qué copia REGENERABLE se edita? (A) instalada global → deriva el relativo para nombrar su fuente;
# (B) clon infra oculto → avisa directo (no hay "fuente correspondiente" que ofrecer: la fuente es el
# clon de DESARROLLO, que este guard no localiza de forma fiable).
case "$fp" in
  "$HOME/.claude/skills/"*) relsub="skills/${fp#"$HOME/.claude/skills/"}" ;;
  "$HOME/.claude/hooks/"*)  relsub="hooks/${fp#"$HOME/.claude/hooks/"}" ;;
  "$HOME/.cortex/brain/"*|"$HOME/.claude-brain/brain/"*)
    MSG="AVISO (proteger-fuente-cerebro): estás editando el CLON INFRA del cerebro ($fp). Ese clon (~/.cortex) es REGENERABLE: el updater del widget lo FUERZA-ALINEA a origin/main (git checkout -B main origin/main) y tu edición en sitio se PIERDE sin rastro. NO es una fuente editable — es un DESPLIEGUE que TODAS las máquinas tienen. Edita la FUENTE en tu clon de DESARROLLO de cortex (p.ej. ~/code/cortex), en una ramita, y propaga por git (ramita→MR→develop). Si esta máquina no tiene clon de desarrollo, no lo edites a mano: contribúyelo por git. (AVISA, no bloquea; CLAUDE_SKIP_PROTEGER_FUENTE=1 para silenciar.)"
    jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
    exit 0
    ;;
  *) exit 0 ;;
esac

# --- Caso (A): resuelve el clon canónico y avisa sólo si existe la FUENTE correspondiente. ---
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
