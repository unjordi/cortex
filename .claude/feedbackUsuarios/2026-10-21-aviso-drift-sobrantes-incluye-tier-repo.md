# aviso-drift-cerebro: en repo PERSONAL manda a borrar hooks de tier `repo` (incluye dod-verificar)

- Medido por claudio-master en la cachy (hook global instalado, cortex develop 52d2d8c):
  `cd ~/code/axon && CLAUDE_PROJECT_DIR=$PWD bash ~/.claude/hooks/aviso-drift-cerebro.sh </dev/null`
  → "🧹 REPO PERSONAL con guards del cerebro que SOBRAN: dod-verificar.sh juez-comun.sh recordar-cosechar.sh sesion-inicio.sh sincronizar-tasklist.sh … Quítalos".
- brain/hooks/MANIFEST: dod-verificar, sesion-inicio, recordar-cosechar = `repo`; sincronizar-tasklist = `repo` (lib); juez-comun = `both` (lib, pero la usa dod-verificar por-repo).
- Debe: listar SOLO los de tier `both` (lo que `sincronizar-cerebro.sh --limpiar-personal` sí retira; la norma dice "nunca los de tier repo"). Tier `repo` no tiene copia global: si se siguen las instrucciones, el repo se queda SIN DoD (el Stop global de la cachy solo trae exportar-sesion-master). Y juez-comun no puede salir mientras dod-verificar siga por-repo.
- Lo detectó axon-master (no tocó nada: "si las quito, te quedas sin DoD") y unjordi lo vio como "algo drifteado".
- Al arreglarlo: test con un repo personal que traiga dod-verificar+juez-comun+sesion-inicio por-repo → el aviso NO los lista; con un guard `both` (p. ej. git-branch-guard) → sí.

- DUPLICADO de N4 (estado-proyecto, inbox 2026-10-10); la decisión de unjordi que lo resuelve está en 2026-10-21-tiers-hooks-repo-a-global.md.
