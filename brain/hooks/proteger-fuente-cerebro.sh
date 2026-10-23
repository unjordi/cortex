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

# El JSON del hook llega por stdin; lo capturamos UNA vez (stdin se consume) y jq sobre la variable.
input=$(cat 2>/dev/null || true)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$fp" ] && exit 0

# resuelve el clon canónico (BRAIN_DIR) — lazy, reusado por el caso (A) y por el de settings.json.
# resolve_brain_dir() vive en drift-cerebro-comun.sh (misma carpeta): $CLAUDE_BRAIN_DIR → ~/.cortex →
# ~/.claude-brain (mismo orden/fallback que los widgets #322). Sin la lib → default histórico (fail-open).
_resolve_brain() {
  local _selfdir; _selfdir="$(dirname "$0")"
  if [ -f "$_selfdir/drift-cerebro-comun.sh" ]; then
    # shellcheck source=drift-cerebro-comun.sh
    . "$_selfdir/drift-cerebro-comun.sh"; BRAIN_DIR="$(resolve_brain_dir)"
  else
    BRAIN_DIR="${CLAUDE_BRAIN_DIR:-$HOME/.cortex}"
  fi
}

# settings.json: AVISO DIRIGIDO (MEDIO auditoría 2026-10-22) — editar TU PROPIO candado. Solo avisa si el
# Edit/Write (a) QUITA/cambia el cableado de un hook del cerebro (nombre en brain/hooks/MANIFEST), o
# (b) AGREGA un ESCAPE de guard en el settings. NO en toda edición (ahí viven permisos/env legítimos que se
# tocan seguido → avisar siempre sería ruido). Límite honesto: un `jq … > settings.json` por Bash NO pasa
# por este hook (es PreToolUse/{Edit,Write,MultiEdit} solamente).
_settings_check() {
  local inp="$1" f="$2" tool old new hit="" nm names manifest
  # Escapes/perillas de guard que, puestos en el env de settings.json, el hook SÍ hereda (a diferencia de un
  # `FOO=1 git …` inline, que solo afecta a ESE comando). Incluye CUALQUIER CLAUDE_*JUEZ* (redirige/afloja el
  # juez de SEGURIDAD de merge/dod: backend local, URL remota, modelo, piso de cita, timeouts, votos).
  local esc_re='CLAUDE_GIT_GUARD_SEED|CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL|CLAUDE_SKIP_[A-Z_]+|CLAUDE_[A-Z_]*JUEZ[A-Z_]*'
  tool=$(printf '%s' "$inp" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in
    MultiEdit)
      old=$(printf '%s' "$inp" | jq -r '[.tool_input.edits[]?.old_string] | join("\n") // empty' 2>/dev/null)
      new=$(printf '%s' "$inp" | jq -r '[.tool_input.edits[]?.new_string] | join("\n") // empty' 2>/dev/null) ;;
    Write)
      new=$(printf '%s' "$inp" | jq -r '.tool_input.content // empty' 2>/dev/null)
      old=$( { [ -f "$f" ] && cat "$f" 2>/dev/null; } || true ) ;;   # overwrite: el "antes" es el archivo en disco
    *)  # Edit
      old=$(printf '%s' "$inp" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
      new=$(printf '%s' "$inp" | jq -r '.tool_input.new_string // empty' 2>/dev/null) ;;
  esac
  # (b) AGREGA un escape de guard: aparece en lo NUEVO y NO en lo viejo.
  if printf '%s' "$new" | grep -qE "$esc_re" && ! printf '%s' "$old" | grep -qE "$esc_re"; then
    hit="agrega un ESCAPE de guard en el settings ($(printf '%s' "$new" | grep -oE "$esc_re" | sort -u | tr '\n' ' '))"
  fi
  # (a) QUITA/cambia el cableado de un hook del cerebro: su <nombre>.sh está en lo viejo y NO en lo nuevo.
  _resolve_brain
  manifest="$BRAIN_DIR/brain/hooks/MANIFEST"
  if [ -f "$manifest" ]; then
    names=$(grep -vE '^[[:space:]]*#' "$manifest" 2>/dev/null | awk '{print $1}' | grep -E '^[A-Za-z0-9_-]+$')
    while IFS= read -r nm; do
      [ -n "$nm" ] || continue
      if printf '%s' "$old" | grep -qF "$nm.sh" && ! printf '%s' "$new" | grep -qF "$nm.sh"; then
        hit="${hit:+$hit; }quita/cambia el cableado del hook del cerebro '$nm' (el command apuntaba a $nm.sh)"
        break
      fi
    done <<EOF
$names
EOF
  fi
  [ -z "$hit" ] && return 0
  local MSG="AVISO (proteger-fuente-cerebro): este Edit/Write a tu settings.json $hit. Eso cambia TU PROPIO candado de supervisión (norma dura 'Integridad de los guardarraíles'): un control de supervisión se afloja/retira SOLO con OK EXPLÍCITO de unjordi para ESE control, nunca por conveniencia. Si de verdad lo autorizó, adelante; si no, deshazlo. (AVISA, no bloquea. Límite: un \`jq … > settings.json\` por Bash NO pasa por este hook; CLAUDE_SKIP_PROTEGER_FUENTE=1 para silenciar.)"
  jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
}

# ¿Qué copia REGENERABLE se edita? (A) instalada global → deriva el relativo para nombrar su fuente;
# (B) clon infra oculto → avisa directo (no hay "fuente correspondiente" que ofrecer: la fuente es el
# clon de DESARROLLO, que este guard no localiza de forma fiable).
_cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"   # honra el override de Claude Code para ~/.claude
case "$fp" in
  "$_cfg/skills/"*) relsub="skills/${fp#"$_cfg/skills/"}" ;;
  "$_cfg/hooks/"*)  relsub="hooks/${fp#"$_cfg/hooks/"}" ;;
  "$HOME/.cortex/brain/"*|"$HOME/.claude-brain/brain/"*)
    MSG="AVISO (proteger-fuente-cerebro): estás editando el CLON INFRA del cerebro ($fp). Ese clon (~/.cortex) es REGENERABLE: el updater del widget lo FUERZA-ALINEA a origin/main (git checkout -B main origin/main) y tu edición en sitio se PIERDE sin rastro. NO es una fuente editable — es un DESPLIEGUE que TODAS las máquinas tienen. Edita la FUENTE en tu clon de DESARROLLO de cortex (p.ej. ~/code/cortex), en una ramita, y propaga por git (ramita→MR→develop). Si esta máquina no tiene clon de desarrollo, no lo edites a mano: contribúyelo por git. (AVISA, no bloquea; CLAUDE_SKIP_PROTEGER_FUENTE=1 para silenciar.)"
    jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
    exit 0
    ;;
  "$_cfg/settings.json"|"$_cfg/settings.local.json"|*/.claude/settings.json|*/.claude/settings.local.json)
    _settings_check "$input" "$fp"
    exit 0
    ;;
  *) exit 0 ;;
esac

# --- Caso (A): resuelve el clon canónico y avisa sólo si existe la FUENTE correspondiente. ---
_resolve_brain
src="$BRAIN_DIR/brain/$relsub"

# Sin fuente correspondiente → skill/hook puramente local → NO es este error → silencio.
[ -f "$src" ] || exit 0

MSG="AVISO (proteger-fuente-cerebro): estás editando la copia INSTALADA del cerebro ($fp). Es REGENERABLE: el próximo install-brain la SOBRESCRIBE con la fuente y tu edición se PIERDE sin rastro. Edita la FUENTE en: $src — y propaga con install-brain (global) o sincronizar-cerebro.sh (por-repo). Corre verificar-cerebro para ver TODO el drift instalada-vs-fuente. (Esto AVISA, no bloquea: si de verdad es un tweak local desechable, ignóralo o exporta CLAUDE_SKIP_PROTEGER_FUENTE=1.)"

jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
