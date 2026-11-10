# Tiers: recordar-cosechar y sesion-inicio pasan a `both`; dod-verificar se queda `repo` (sin el bug del aviso)

Decisión de unjordi 2026-10-21 [user: "estado-proyecto.md debería existir en todos lados, no solo en repos, así que recordar-cosechar de todos modos debería estar en todos lados.. el único que suena a que no puede ir gloal es dod-verificar, pero sin ese bug, plz. no sé por qué tiene tanto hardcoding, pero luego lo revisamos."]

1. `recordar-cosechar` (+ su lib `sincronizar-tasklist`) y `sesion-inicio` → tier `both` (global por bootstrap + por-repo con dedupe). Medido por claudio: los tres son fail-open/no-op sin los archivos del proyecto; nada los ata a un repo.
2. "estado-proyecto.md debería existir en todos lados, no solo en repos": hoy recordar-cosechar no lo crea (`[ -f estado-proyecto.md ] || return 0`). Cómo se cumple (crearlo, avisar, dónde vive fuera de un repo, p. ej. GoogleDrive/Juegos de games-master) es diseño tuyo: propónselo a unjordi antes de implementarlo.
3. `dod-verificar` sigue tier `repo`, y el aviso de aviso-drift-cerebro deja de marcarlo como sobrante (= N4 de estado-proyecto, y la nota 2026-10-21-aviso-drift-sobrantes-incluye-tier-repo.md, que es su duplicado con reproductor). Con 1 resuelto, los únicos tier-repo en un repo personal serían dod-verificar y la lib que usa (juez-comun): el aviso no debe listarlos.
4. Backlog (sin prioridad, "luego lo revisamos"): revisar el hardcoding de dod-verificar.

Cada cambio con su test de uso real (repo personal desechable: tras el bootstrap, recordar-cosechar y sesion-inicio corren desde el global; el aviso no lista dod-verificar/juez-comun; un guard `both` duplicado sí).
