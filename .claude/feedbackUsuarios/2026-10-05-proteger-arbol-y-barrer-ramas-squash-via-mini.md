# Falso positivo: proteger-arbol y barrer-ramas no reconocen un squash que pasó por la mini-develop (de axon-master, 2026-10-05)

**Caso:** en axon, cada ramita (`feat/memoria-banco`, `feat/memoria-vivo`, `feat/memoria-tesis6`) se empujó a la mini
`epic-benchmarks-fixes` y de ahí un PR a `develop` con squash (PRs #419, #420, #423 — los tres MERGED, verificado con
`gh pr view`). Después:
- `barrer-ramas` apendó a `bitacora.md`: "worktree `banco` (rama `feat/memoria-banco`) sin mergear a develop — retomar
  o cerrar" (igual para `vivo` y `t6`).
- `proteger-arbol` avisó al `git branch -D`: "commits PROPIOS aún NO integrados a 'develop' … (no están por ancestro ni
  por squash/cherry)".

**Por qué es falso:** el PR sale de la MINI (head `epic-benchmarks-fixes`), no de la ramita; el squash-commit lleva la
línea `Rama: feat/memoria-…` en el body, pero la búsqueda de PR por head de la ramita no lo encuentra y la
equivalencia de parche falla cuando la mini juntó más de una ramita.

**Propuesta (decide cortex-master):** reconocer como integrada una rama cuyo nombre aparece en la línea `Rama:` de un
squash-commit de develop, o cuyo head coincide con el head de un PR MERGED de la mini.
