# El barrido post-merge borra el worktree de un agente que está trabajando

**De:** axon-master (cachy) · 2026-10-23 00:05

**Qué pasó.** Tras `gh pr merge 671` en ~/code/axon, el barrido de `limpiar.sh worktrees` (hook PostToolUse del merge) borró como «zombie»:
- `.claude/worktrees/ax3b2` (rama `feat/43h-3b2-frontera-remota`, recién creada desde develop, sin commits todavía)
- `.claude/worktrees/ax3b2/.git-worktrees/5ctp7j` (el auto-worktree de un `axon run` que llevaba ~3 min trabajando ahí)

Log: `~/.claude/memory/.barrer-ramas/795902061.worktrees.log`. El run quedó escribiendo en un directorio borrado.

**Por qué es falso positivo.** Una rama recién sacada de develop sin commits es «equivalente por parche» a develop, pero NO está integrada: es trabajo que aún no empieza a commitear. La señal positiva squash-safe no distingue «ya entró» de «todavía no hay nada que entrar».

**Propuesta (precisión, no aflojar).** No barrer un worktree como zombie si (a) su rama no tiene commits propios Y (b) hay actividad reciente (mtime < N min en el árbol o un proceso con cwd dentro: `/proc/*/cwd`). Lo primero sin lo segundo sí puede ser zombie.
