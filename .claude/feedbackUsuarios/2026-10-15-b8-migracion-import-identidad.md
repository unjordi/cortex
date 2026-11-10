# B8: falta la migración del @import en los repos que ya existen (medido por claudio-master)

b0fdbdd quita la reinyección de identidad de aviso-drift-cerebro y deja la carga SOLO al `@import` del CLAUDE.md. En la épica, el CLAUDE.md de cortex sí lo trae (línea 73). Pero los otros repos con identidad NO:

| repo | Mac | cachy |
|---|---|---|
| plantilladotnet (claudio-master) | sin @import | sin @import |
| axon (axon-master) | sin @import | sin @import |

Medido con: archivo `.claude/memory/conocimiento-propio*.md` presente y ningún `^@.*conocimiento-propio` en CLAUDE.md, CLAUDE.local.md ni .claude/CLAUDE.md.

**Consecuencia:** al instalar la épica desde develop (plan de cierre), claudio-master y axon-master arrancan SIN identidad.

**Arreglo que propongo (mecanismo, no paso manual):** al instalar o sincronizar, si un repo tiene `.claude/memory/conocimiento-propio.local.md` y ningún @import de él, se agrega `@.claude/memory/conocimiento-propio.local.md` al **CLAUDE.local.md** (gitignored: en un repo compartido como plantilladotnet NO va al CLAUDE.md del equipo). Idempotente, con su test (repo con identidad y sin @ → lo agrega una vez; con @ → no toca; sin identidad → no toca). Tiene que estar ANTES de la instalación de cierre.

## Revisión de aa51ae1 (claudio-master)
Bien: los 4 casos del test (cablea una vez · idempotente · respeta un @import existente · sin identidad no toca).

**Hueco:** `CLAUDE.local.md` NO está ignorado por git en axon (Mac y cachy; medido con `git check-ignore`). En plantilladotnet sí. Donde no existe, el hook lo CREA → queda untracked y un `git add -A` lo commitea al repo.
**Arreglo propuesto:** antes de crear o escribir `CLAUDE.local.md`, si `git check-ignore -q CLAUDE.local.md` falla, agregar `CLAUDE.local.md` a `.git/info/exclude` (per-clon, no toca el `.gitignore` versionado). Test: repo sin la regla de ignore → tras la sesión, `git status --porcelain` no muestra `CLAUDE.local.md`.
