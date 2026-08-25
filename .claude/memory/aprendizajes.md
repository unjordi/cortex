# Aprendizajes — inbox del equipo (append-only, con atribución)

---
### 2026-08-07 · unjordi · Irse de boca a sidequests quema contexto → compact → pérdida
unjordi lo señaló **3 veces** en una sesión: cada ítem chico que aparecía, Claude lo convertía en un
sprint de ejecución completo (worktree + commit + PR + task) y perdía el hilo que unjordi steerea. **El
costo real NO es el token del sidequest — es el contexto quemado y lo que el compact se lleva después.**
Regla: quedarse SOLO en el hilo activo; los ítems que surjan se **BACKLOGUEAN en una línea**, no se
ejecutan al vuelo. "Rescata X" dicho al pasar sigue siendo sidequest si no es el hilo del momento.

### 2026-08-07 · unjordi/Claude · Verificar contra git, NUNCA de memoria
Claude se tropezó **3×** afirmando que `juez-comun.sh` "no existía" / "es archivo nuevo" — por mirar el
working tree en una rama **stale** (chore, 15 commits atrás de develop) en vez de `origin/develop`/`main`.
Antídotos: `git cat-file -e origin/<rama>:<archivo>`, `git log --oneline -- <archivo>`, y **parquear el
working tree en develop** (dejarlo en una rama vieja muerde repetido). Confabular con seguridad cuesta más
que un "déjame verificar". Corolario: un auditor que corre sobre un árbol stale da hallazgos contaminados
(re-validar vs develop).

### 2026-08-07 · unjordi · read-before-overwrite del hilo mental
Antes de sobreescribir `hilo-mental-actual.md`, **leerlo** — sobre todo tras un incidente donde cargar una
sesión stale lo clobbereó. Claude lo saltó una vez (escribió desde contexto); unjordi lo cazó. El feature
#272 lo enforza en el skill checkpoint, pero no está vivo hasta el release → aplicarlo a mano mientras tanto.

### 2026-08-07 · unjordi · Un gate-LLM se afina en el PROMPT, no con más capas encima
El bug del juez de merge NO era "qué opina Haiku hoy": Haiku juzgaba bien. Lo traicionaba un veto de cita
**byte-exacto** (`grep -Fq`) que se rompía cuando el LLM "corregía" un typo del usuario al citar. Palabras
de unjordi: *"no supe pedirle las cosas a Haiku por andar queriendo acotarlo"*. Lección: containment de
tokens > eco byte-exacto; una capa determinista de seguridad debe tolerar normalización benigna sin aflojar
el invariante. Doble auditoría independiente (una a ciegas) fue lo que lo destapó — no el autodiagnóstico.
