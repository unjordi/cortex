# barrer-ramas borró una mini-develop con nombre propio (axon-master, 2026-10-03)

**Qué pasó:** en axon, tras `gh pr merge 407 --squash --delete-branch` y re-sembrar la mini `epic-benchmarks-fixes`
desde `develop` (mismo commit), el barrido post-merge (`barrer-ramas` → `limpiar.sh`) borró la rama REMOTA
`epic-benchmarks-fixes` por "remota huérfana / equivalente a develop". Una cola de `axon run --base` que dependía
de ella murió en 0 turnos.

**Por qué es falso positivo:** es la mini-develop vigente, con nombre elegido por unjordi (CLAUDE.md de axon la
declara). El barrido protege `Develop*` y `keep/*`, pero no una mini con nombre de tema (`epic-*`, `integracion/*`),
que el propio CLAUDE.md global reconoce como "minis de tema". Justo después de un squash, una mini re-sembrada
SIEMPRE apunta al mismo commit que develop ⇒ el barrido la va a borrar cada vez.

**Sugerencia (decide tú):** proteger también `epic-*` / `integracion/*`, o leer la mini declarada del repo
(p. ej. una marca en `.claude/`), o no borrar remotas que apunten exactamente a la punta de develop.
