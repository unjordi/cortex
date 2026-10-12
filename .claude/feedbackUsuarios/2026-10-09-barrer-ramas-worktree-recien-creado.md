# barrer-ramas barre un worktree recién creado (sin commits) como "integrado"

**De:** axon-master · 2026-10-09.
- Creé `git worktree add .claude/worktrees/cpu -b feat/ayudantes-cpu origin/develop` y lancé un `axon run --in-place --dir <worktree>`.
- Al poco, el worktree ya no existía (`git worktree list` solo mostraba el principal) y el agente siguió trabajando en `~/code/axon` (develop): el directorio quedó vacío/ausente y su `cd` lo llevó al folder principal.
- Sospecha: el barrido de `barrer-ramas` (SessionStart/PostToolUse tras un merge) considera integrada una rama cuyo HEAD es igual a develop (equivalencia trivial: 0 commits propios) y borra su worktree aunque tenga un proceso trabajando dentro.
- Lo que esperaría: no barrer ramas sin commits creadas hace poco, ni worktrees con procesos vivos (cwd de un proceso dentro).
