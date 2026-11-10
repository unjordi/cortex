#!/usr/bin/env bash
# [fondo] Hook PreToolUse de Bash: baja el timeout de cada llamada en primer plano a CLAUDE_FONDO_MS (15000).
# Lo que tarde más lo pasa Claude Code al fondo y avisa al terminar. Las llamadas con run_in_background o con
# un timeout menor no se tocan.
command -v jq >/dev/null 2>&1 || exit 0
ms="${CLAUDE_FONDO_MS:-15000}"
case "$ms" in ''|*[!0-9]*) ms=15000 ;; esac
jq -c --argjson ms "$ms" '
  .tool_input as $t
  | if ($t.run_in_background // false) or (($t.timeout // 1e12) <= $ms) then empty
    else {hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:($t + {timeout:$ms})}} end' 2>/dev/null
exit 0
