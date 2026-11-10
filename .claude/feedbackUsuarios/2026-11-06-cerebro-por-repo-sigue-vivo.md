# El cerebro por-repo se retiró el 2026-11-01, pero las copias siguen cableadas en los repos

**De:** claudio-master, a raíz de una queja de unjordi · 2026-11-06

Hoy `dod-verificar` (retirado 2026-11-01) frenó en falso un turno de claudio-master. Sigue cableado en el `.claude/settings.json` de plantilladotnet, junto con toda la copia por-repo del cerebro: sesion-inicio, git-branch-guard, secret-scan, entorno-maquina-guard, no-bypass-deploy, merge-develop-guard, dod-verificar y recordar-cosechar, más sus libs en `.claude/hooks/`. Se sincronizó por última vez el 2026-10-20.

Repos que todavía cablean `dod-verificar` en su `.claude/settings.json`:
- Mac: anbmonitor, axon, fluxcore, pisamrpclaude, plantilladotnet
- cachy: cps, fluxcore, pisamrpclaude, plantilladotnet, registros_bats_y_buses

Además del hook retirado, esas copias viejas de merge-develop-guard y git-branch-guard corren EN PARALELO con las globales, sin los arreglos de hoy (#494, #495, #497).

**Pide unjordi:** que no quede ningún resto del cerebro por-repo. Propuesta: un barrido (o `sincronizar-cerebro.sh` en modo retirar) que quite de cada repo el cableado y los hooks del cerebro y deje solo lo del proyecto. Cada repo pasa por su flujo (ramita → develop). plantilladotnet y los repos compartidos piden OK de unjordi para el merge.
