# vigilar-master: falso COLGADO tras un compact en idle

Tras «Compacted while idle», el transcript queda con: `user` (isCompactSummary=true) → `system compact_boundary` → `system informational`. El vigilante toma el último como evento de conversación ≠ fin de turno y a los 12 min emite COLGADO con el master ocioso (cortex-master, 2026-10-16T00:52Z).

Arreglo en la copia de claudio (`~/.claude/skills/coordinar-claudes/vigilar-master.sh`), verificado contra ese transcript (el último evento pasa a ser `compact_boundary`):
- selector: `(.type=="user" and .isCompactSummary!=true)` y `(.type=="system" and .subtype!="informational")`
- fin de turno: agregar `compact_boundary`

Falta el caso al banco `vm:` (fixture con esa secuencia, que falle contra cb101e2).
