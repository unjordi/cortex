# Entorno de máquina: dos archivos con drift; la fuente única es la LEAN (de claudio-master, 2026-10-09)

**Qué pasó:** en la Mac convivían `~/.claude/entorno-maquina.md` (LEAN, importada por `~/.claude/CLAUDE.md`) y
`~/.claude/projects/-Users-unjordi/memory/entorno-esta-maquina.md` (detalle). Driftearon: la detallada seguía diciendo
que el Bash tool corre zsh 5.9 cuando desde el 2026-09-10 corre bash 5.3. unjordi decidió: la canónica es la LEAN
[user: "(~/.claude/entorno-maquina.md) era la canónica!!!!"; "borra la detallada!! … si tiene algo útil y único que NO
ESTÉ RANCIO, muévelo a la LEAN"]. Hecho: lo útil se movió a la LEAN y la detallada se mandó a la Papelera.

**Por qué te toca:** `install-brain.sh` (líneas ~440-507) siembra/refresca `entorno-esta-maquina.md` en la memoria
global, y la norma "El entorno de MÁQUINA vive GLOBAL" del bloque cortex de `~/.claude/CLAUDE.md` (y el
`entorno-maquina-guard`) nombran `entorno-esta-maquina.md` como su casa. En el próximo update el archivo detallado
vuelve a nacer y el drift regresa.

**Propuesta (decide el master):** que install-brain siembre/refresque la LEAN `~/.claude/entorno-maquina.md` (o su
bloque detectado) en vez del detallado, y que la norma y el guard apunten a ella como fuente única.

**Estado 2026-10-09:** corregido por claudio-master con OK de unjordi [user: "por esta vez, corrígelo"] en la rama local `fix/entorno-lean-fuente-unica` (7c526b4, worktree `.claude/worktrees/entorno-lean`). test-brain: 1361 PASS · 0 FAIL. Pendiente: integrarlo a develop.
**Integrado 2026-10-09:** PR #463 → develop (803eb9a). La develop LOCAL de cortex sigue con 7 commits propios sin pushear; falta su pull/rebase sobre origin/develop.
