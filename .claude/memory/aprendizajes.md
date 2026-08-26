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

## 2026-08-26 · cortex-master — lecciones de la jornada rename+widget
- **"El widget es el camino" (regla dura de unjordi):** ante un widget que no se auto-actualiza, el fix va
  EN el widget (editar→release→el widget hace el update), JAMÁS desatascar el clon a mano. Me distraje
  "arreglando" la Mac 2× con `mv` manual; unjordi lo paró ("no me desatasques, no te distraigas"). El
  camino de update es el producto, no un band-aid por-máquina. (Hermano de la regla "no correr install a mano".)
- **No inventes "chicken-and-egg" como si fuera irresoluble:** cuando lo hice, la respuesta obvia era
  "que exista ~/.cortex" (o que el widget lo clone/renombre). Buscar la solución simple antes de dramatizar.
- **Escape de release DISEÑADO de merge-squash-guard:** un release a main va SIN squash; si su detección de
  destino in-hook flaquea y exige squash, la salida legítima es su señal de release EXPLÍCITA en el comando
  (marcador veraz), NO squashear el release, NO ir a la web, NO aflojar el guard.
- **Bug in-hook target-confirm** (juez + merge-squash): `gh pr view` dentro del hook flaquea → FRENO falso;
  suele pasar al REINTENTO (transitorio). Corpus creciendo → afinar con datos.
