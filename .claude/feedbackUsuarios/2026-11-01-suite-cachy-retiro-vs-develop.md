# Suite completa en la cachy: fix/retiro-cerebro-por-repo (3a21cae) vs develop (deeb2a5)

Corrida por claudio-master, 2026-11-01, worktrees en /tmp de la cachy. Logs: cachy:/tmp/tb-retiro.log y cachy:/tmp/tb-develop.log.
- develop: 1590 PASS · 6 FAIL
- rama:    1394 PASS · 12 FAIL (el total baja por las baterías per-repo retiradas)

## Regresiones de la rama (fallan en la rama y NO en develop)
1. drift-widget[mac]: known-repo DIFIERE de MANIFEST · sobran/faltan: ~ cerrar-slice. La lista que el widget de Mac conoce quedó desfasada del MANIFEST de skills.
2. (e2e) paridad: T4 no explica la bifurcación personal/compartido · (e2e) paridad: un destino COMPARTIDO sin settings.json pasó. Esperan la bifurcación de reubicar-master que la fila 13 retiró a propósito: hay que reescribir esos dos asertos al contrato nuevo (solo cerebro global), no restaurar la bifurcación.
3. e6c4 (leyenda de los .dot), e6c5 (.svg que citan dod-verificar y no traen mandato-loop), f3 (baseline de flowcharts). Son de las filas 11 y 14; se cierran con ellas.

## Fallan YA en develop (no son de la rama, pero el lote no debería integrarse con ellos en rojo)
4. A2/M4: `--dry-run` MUTÓ CLAUDE.md (el bloque (e2) @import no respetó el dry-run). Bug real: un dry-run no escribe.
5. verificar-cerebro drift: no marcó la dirección.
6. arbol: DRIFT entre catálogos · f2: baseline en paridad ❌ (README.md/MEMORY.md).
7. juez-comun (a·#2) y (a3·#2): 401 del llavero / EXPIRED. Revisar si es del entorno de la cachy (llavero de Linux) o del código; si es del entorno, que el test diga SKIP y no FAIL.

Propuesta: 1 y 2 como parte de las filas 1/13; 3 con 11/14; 4-7 como filas nuevas del lote, porque la integración necesita la suite en verde.
