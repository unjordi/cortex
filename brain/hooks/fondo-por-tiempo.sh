#!/usr/bin/env bash
# [fondo] Hook PreToolUse de Bash: baja el timeout de cada llamada en primer plano a CLAUDE_FONDO_MS (15000).
# Lo que tarde más lo pasa Claude Code al fondo y avisa al terminar. Las llamadas con run_in_background o con
# un timeout menor no se tocan. Una llamada SIN timeout se mide contra BASH_DEFAULT_TIMEOUT_MS (el default de
# Claude Code, 120000 si no está): si ese default ya cabe en el umbral no se reescribe, porque reescribir la
# llamada deja al clasificador de auto mode sin veredicto. Prueba: (fpt) en test-brain.sh.
command -v jq >/dev/null 2>&1 || exit 0
ms="${CLAUDE_FONDO_MS:-15000}"
case "$ms" in ''|*[!0-9]*) ms=15000 ;; esac
def="${BASH_DEFAULT_TIMEOUT_MS:-120000}"
case "$def" in ''|*[!0-9]*) def=120000 ;; esac
jq -c --argjson ms "$ms" --argjson def "$def" '
  .tool_input as $t
  | if ($t.run_in_background // false) or (($t.timeout // $def) <= $ms) then empty
    else {hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:($t + {timeout:$ms})}} end' 2>/dev/null
exit 0
