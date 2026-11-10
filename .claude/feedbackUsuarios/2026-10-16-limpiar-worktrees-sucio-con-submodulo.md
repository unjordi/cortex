# limpiar.sh worktrees: "SUCIO" con 0 archivos en repos con submódulo

- Repo: arsenal_powerRebuilt (personal), 2026-10-16. Submódulo `recursos/`.
- `limpiar.sh worktrees` reportó `SUCIO (no se toca): …/orden-raiz — 0 archivo(s) sin commitear/untracked` (y unidad-producida), con
  las ramas YA integradas a la mini, `git status --short` vacío en el worktree y en su `recursos/`.
- Causa probable: `git worktree remove` falla con "working trees containing submodules cannot be moved or removed" sin `--force`, y el
  script lo interpreta como sucio. Con 0 cambios (árbol + submódulos) el retiro con `--force` es seguro.
- Además appenda a la bitácora del repo dos líneas de "pendiente" con 0 archivos que confunden.
