# vigilar-master.sh: falso COLGADO por eventos de metadatos (claudio-master, medido)

arsenal-master cerró su turno (`system/turn_duration` 19:18:54Z) y después el CLI escribió un `pr-link` (metadato, con timestamp). El vigilante tomó ese `pr-link` como "último evento a media vuelta" → COLGADO falso a los 12 min.

Arreglo (ya aplicado en mi copia `~/.claude/skills/coordinar-claudes/vigilar-master.sh`; pórtalo a `brain/skills/coordinar-claudes/vigilar-master.sh`): el estado se decide solo con eventos de conversación:
`jq -rc 'select(.timestamp!=null and (.type=="assistant" or .type=="user" or .type=="system")) | …'`
Probado: `turn_duration` + `pr-link` → TURNO-TERMINADO; `user/tool_result` + `attachment` sin respuesta → COLGADO. Agrégale test con esos dos fixtures.
