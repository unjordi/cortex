# El barrido post-merge escribe en la bitácora del worktree donde ocurrió el merge

- Visto 2026-10-27 por axon-master en ~/code/axon: tras cada `gh pr merge` corrido desde un worktree de feature (`.claude/worktrees/s10-*`), el hook de barrido appendea un bloque `- **[worktrees pendientes tras barrido]**` con la lista de worktrees sin integrar al `.claude/memory/bitacora.md` DE ESE WORKTREE.
- Efecto: el worktree queda con un cambio sin commitear que no es del feature; `git rebase` se niega ("cambios sin marcar") y `git worktree remove` pide `--force`. Pasó en 3 worktrees distintos en una tarde.
- Además, "sin mergear a develop" es falso para ramas que van a una rama de integración (`epic/*`): ya están integradas a su base.
- Sugerencia: escribir esa nota en la bitácora del folder principal (o en el log del barrido), nunca en un worktree; y medir "integrada" contra la base real del PR.
